// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "remote-cli",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../../packages/RemoteKit")],
    targets: [
        .executableTarget(name: "remote-cli", dependencies: ["RemoteKit"]),
    ]
)
