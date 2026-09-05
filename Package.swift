// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "shotkit",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "shotkit", path: "Sources/shotkit")
    ]
)
