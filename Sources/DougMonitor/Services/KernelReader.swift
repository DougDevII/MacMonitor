// Copyright © 2026 Douglas Almeida dos Santos. Todos os direitos reservados.
import Darwin
import Foundation
import MonitorCore

/// Native read-only counters. No shell commands, helpers, root access or sensors.
struct KernelReader {
    private var previousCPU: CPUTicks?
    private var previousNetwork: [String: NetworkCounters] = [:]
    private var previousTime: TimeInterval?

    mutating func reset() {
        previousCPU = nil; previousNetwork = [:]; previousTime = nil
    }

    mutating func sample(available: Bool, connection: String) -> MetricSnapshot {
        let now = ProcessInfo.processInfo.systemUptime
        let cpuTicks = Self.readCPU()
        let network = Self.readNetwork()
        let elapsed = previousTime.map { now - $0 } ?? 0
        let cpu = cpuTicks.flatMap { ticks in previousCPU.flatMap { ticks.usage(since: $0) } }
        let rate = network.map {
            NetworkRate.between(previous: previousNetwork, current: $0, elapsed: elapsed)
        } ?? .init()
        previousCPU = cpuTicks
        previousNetwork = network ?? [:]
        previousTime = now
        return MetricSnapshot(cpu: cpu, memoryUsed: Self.readMemory(), rate: rate,
                              networkAvailable: available, connection: connection,
                              interfaces: network?.keys.sorted() ?? [])
    }

    private static func readCPU() -> CPUTicks? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return CPUTicks(user: info.cpu_ticks.0, system: info.cpu_ticks.1,
                        idle: info.cpu_ticks.2, nice: info.cpu_ticks.3)
    }

    private static func readMemory() -> UInt64? {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else { return nil }
        return MemoryUsage.bytes(internalPages: UInt64(info.internal_page_count),
                                 purgeablePages: UInt64(info.purgeable_count),
                                 wiredPages: UInt64(info.wire_count),
                                 compressedPages: UInt64(info.compressor_page_count),
                                 pageSize: UInt64(pageSize),
                                 physicalMemory: ProcessInfo.processInfo.physicalMemory)
    }

    private static func readNetwork() -> [String: NetworkCounters]? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &length, nil, 0) == 0,
              length > 0 else { return nil }
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: length, alignment: MemoryLayout<if_msghdr2>.alignment)
        defer { buffer.deallocate() }
        guard sysctl(&mib, UInt32(mib.count), buffer, &length, nil, 0) == 0 else { return nil }
        var offset = 0
        var result: [String: NetworkCounters] = [:]
        while offset + MemoryLayout<if_msghdr>.size <= length {
            let pointer = buffer.advanced(by: offset)
            let header = pointer.loadUnaligned(as: if_msghdr.self)
            let size = Int(header.ifm_msglen)
            guard size > 0, offset + size <= length else { break }
            if Int32(header.ifm_type) == RTM_IFINFO2, size >= MemoryLayout<if_msghdr2>.size {
                let message = pointer.loadUnaligned(as: if_msghdr2.self)
                var nameBuffer = [CChar](repeating: 0, count: Int(IFNAMSIZ))
                if if_indextoname(UInt32(message.ifm_index), &nameBuffer) != nil {
                    let name = String(decoding: nameBuffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
                    // Physical Ethernet/Wi-Fi only: exclude loopback, VPN, AWDL and bridges
                    // to avoid counting the same packet at multiple layers.
                    if name.hasPrefix("en"), message.ifm_flags & IFF_UP != 0,
                       message.ifm_flags & IFF_RUNNING != 0 {
                        result[name] = NetworkCounters(received: message.ifm_data.ifi_ibytes,
                                                       sent: message.ifm_data.ifi_obytes)
                    }
                }
            }
            offset += size
        }
        return result
    }
}
