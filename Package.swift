// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DougMonitor",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "DougMonitor", targets: ["DougMonitor"])],
    targets: [
        .target(name: "MonitorCore"),
        .executableTarget(name: "DougMonitor", dependencies: ["MonitorCore"]),
        .testTarget(name: "MonitorCoreTests", dependencies: ["MonitorCore"])
    ]
)
