// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "StartGGMatchExporter",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "StartGGMatchExporter",
            targets: ["StartGGMatchExporter"]
        )
    ],
    targets: [
        .executableTarget(
            name: "StartGGMatchExporter",
            linkerSettings: [
                .linkedFramework("Security"),
                .linkedFramework("AppKit")
            ]
        ),
        .testTarget(
            name: "StartGGMatchExporterTests",
            dependencies: ["StartGGMatchExporter"]
        )
    ]
)
