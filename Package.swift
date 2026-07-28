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
    dependencies: [
        .package(
            url: "https://github.com/sparkle-project/Sparkle",
            exact: "2.9.4"
        )
    ],
    targets: [
        .executableTarget(
            name: "FreshProfile",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/FreshProfile"
        ),
        .testTarget(
            name: "FreshProfileTests",
            dependencies: ["FreshProfile"],
            path: "Tests/FreshProfileTests"
        )
    ]
)
