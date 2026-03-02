// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Kolache",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "Kolache",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "KolacheTests",
            dependencies: ["Kolache"]
        ),
    ]
)