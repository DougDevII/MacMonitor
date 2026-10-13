// Copyright © 2026 Douglas Almeida dos Santos. Todos os direitos reservados.
import Foundation

public struct CPUTicks: Sendable {
    public let user: UInt32
    public let system: UInt32
    public let idle: UInt32
    public let nice: UInt32

    public init(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32) {
        self.user = user; self.system = system; self.idle = idle; self.nice = nice
    }

    public func usage(since previous: Self) -> Double? {
        // Mach exports wrapping 32-bit counters. Subtract BEFORE converting.
        let busy = UInt64(user &- previous.user) + UInt64(system &- previous.system)
            + UInt64(nice &- previous.nice)
        let total = busy + UInt64(idle &- previous.idle)
        guard total > 0 else { return nil }
        return min(1, max(0, Double(busy) / Double(total)))
    }
}

public struct NetworkCounters: Sendable {
    public let received: UInt64
    public let sent: UInt64
    public init(received: UInt64, sent: UInt64) {
        self.received = received; self.sent = sent
    }
}

public struct NetworkRate: Sendable, Codable {
    public let download: Double
    public let upload: Double
    public init(download: Double = 0, upload: Double = 0) {
        self.download = download; self.upload = upload
    }

    public static func between(
        previous: [String: NetworkCounters], current: [String: NetworkCounters],
        elapsed: Double
    ) -> Self {
        guard elapsed > 0, elapsed.isFinite else { return .init() }
        var received = 0.0, sent = 0.0
        for (name, counters) in current {
            // A new interface or reset needs a fresh baseline, not a giant spike.
            guard let old = previous[name], counters.received >= old.received,
                  counters.sent >= old.sent else { continue }
            received += Double(counters.received - old.received)
            sent += Double(counters.sent - old.sent)
        }
        return .init(download: received / elapsed, upload: sent / elapsed)
    }
}

public enum MemoryUsage {
    public static func bytes(
        internalPages: UInt64, purgeablePages: UInt64, wiredPages: UInt64,
        compressedPages: UInt64, pageSize: UInt64, physicalMemory: UInt64
    ) -> UInt64 {
        let appPages = internalPages > purgeablePages ? internalPages - purgeablePages : 0
        return min(physicalMemory, (appPages + wiredPages + compressedPages) * pageSize)
    }
}

public struct MetricSnapshot: Sendable, Codable {
    public var cpu: Double?
    public var memoryUsed: UInt64?
    public var memoryTotal: UInt64
    public var rate: NetworkRate
    public var networkAvailable: Bool
    public var connection: String
    public var interfaces: [String]
    public var sampledAt: Date

    public init(cpu: Double? = nil, memoryUsed: UInt64? = nil,
                memoryTotal: UInt64 = ProcessInfo.processInfo.physicalMemory,
                rate: NetworkRate = .init(), networkAvailable: Bool = false,
                connection: String = "Verificando rede…", interfaces: [String] = [],
                sampledAt: Date = Date()) {
        self.cpu = cpu; self.memoryUsed = memoryUsed; self.memoryTotal = memoryTotal
        self.rate = rate; self.networkAvailable = networkAvailable
        self.connection = connection; self.interfaces = interfaces; self.sampledAt = sampledAt
    }

    public var memoryFraction: Double? {
        guard let memoryUsed, memoryTotal > 0 else { return nil }
        return min(1, Double(memoryUsed) / Double(memoryTotal))
    }
}

public enum MetricFormat {
    public static func percent(_ fraction: Double?) -> String {
        guard let fraction, fraction.isFinite else { return "—" }
        return "\(Int((fraction * 100).rounded()))%"
    }

    public static func gigabytes(_ bytes: UInt64) -> String {
        String(format: "%.1f", locale: Locale(identifier: "pt_BR"), Double(bytes) / 1_073_741_824)
    }

    public static func megabits(_ bytesPerSecond: Double) -> String {
        let value = max(0, bytesPerSecond * 8 / 1_000_000)
        return String(format: value >= 100 ? "%.0f" : "%.1f",
                      locale: Locale(identifier: "pt_BR"), value)
    }
}
