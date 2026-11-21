// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CalmCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "CalmCore", targets: ["CalmCore"]),
    ],
    targets: [
        .target(name: "CalmCore"),
        .testTarget(
            name: "CalmCoreTests",
            dependencies: ["CalmCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
