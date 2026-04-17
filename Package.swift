// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacTimeWidget",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MacTimeWidget",
            path: "Sources/MacTimeWidget"
        )
    ]
)
