import XCTest
@testable import MonitorCore

final class MetricsTests: XCTestCase {
    func testCPUIncludesSystemAndNiceAndUsesDelta() {
        let before = CPUTicks(user: 100, system: 50, idle: 500, nice: 10)
        let after = CPUTicks(user: 130, system: 60, idle: 550, nice: 20)
        XCTAssertEqual(after.usage(since: before), 0.5)
        XCTAssertNil(before.usage(since: before))
    }

    func testCPUCounterWrapDoesNotCreateSpike() {
        let before = CPUTicks(user: UInt32.max - 9, system: 0, idle: 20, nice: 0)
        let after = CPUTicks(user: 10, system: 0, idle: 40, nice: 0)
        XCTAssertEqual(after.usage(since: before), 0.5)
    }

    func testNetworkIgnoresNewAndResetInterfaces() {
        let previous = ["en0": NetworkCounters(received: 100, sent: 200),
                        "en1": NetworkCounters(received: 9_000, sent: 9_000)]
        let current = ["en0": NetworkCounters(received: 1_100, sent: 600),
                       "en1": NetworkCounters(received: 0, sent: 0),
                       "en2": NetworkCounters(received: 1_000_000, sent: 1_000_000)]
        let rate = NetworkRate.between(previous: previous, current: current, elapsed: 2)
        XCTAssertEqual(rate.download, 500)
        XCTAssertEqual(rate.upload, 200)
        XCTAssertEqual(NetworkRate.between(previous: previous, current: current, elapsed: 0).download, 0)
    }

    func testMemoryExcludesPurgeableAndCountsCompressedPhysicalPages() {
        XCTAssertEqual(MemoryUsage.bytes(internalPages: 100, purgeablePages: 20, wiredPages: 10,
                                        compressedPages: 5, pageSize: 16_384,
                                        physicalMemory: 8_000_000), 95 * 16_384)
        XCTAssertEqual(MemoryUsage.bytes(internalPages: 10, purgeablePages: 20, wiredPages: 10,
                                        compressedPages: 5, pageSize: 16_384,
                                        physicalMemory: 200_000), 200_000)
    }

    func testNetworkDisplaysBitsNotBytes() {
        XCTAssertEqual(MetricFormat.megabits(1_250_000), "10,0")
        XCTAssertEqual(MetricFormat.percent(nil), "—")
    }
}
