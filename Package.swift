// swift-tools-version: 5.9
// Copyright (c) 2026 LanDen Labs - Dennis Lang
import PackageDescription

let package = Package(
    name: "MacTimeWidget",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MacTimeWidget",
            path: "Sources/MacTimeWidget",
            resources: [.process("Resources")]
        )
    ]
)
