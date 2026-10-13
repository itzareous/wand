// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RemoteKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RemoteKit", targets: ["RemoteKit"]),
    ],
    targets: [
        .target(name: "RemoteKit"),
        .testTarget(name: "RemoteKitTests", dependencies: ["RemoteKit"]),
    ]
)
