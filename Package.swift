// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FreshProfile",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "FreshProfile", targets: ["FreshProfile"])
    ],
    targets: [
        .executableTarget(
            name: "FreshProfile",
            path: "Sources/FreshProfile"
        ),
        .testTarget(
            name: "FreshProfileTests",
            dependencies: ["FreshProfile"],
            path: "Tests/FreshProfileTests"
        )
    ]
)
