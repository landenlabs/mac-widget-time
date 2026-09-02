// swift-tools-version: 5.9
// Copyright (c) 2026 LanDen Labs - Dennis Lang
import PackageDescription

let package = Package(
    name: "MacWidgetTime",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MacWidgetTime",
            path: "Sources/MacWidgetTime",
            resources: [.process("Resources")],
            linkerSettings: [
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
