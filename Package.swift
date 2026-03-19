// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Kolache",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/argylebits/swift-version-plugin.git", from: "1.0.0"),
    ],
    targets: [
        .target(name: "KolacheCore"),
        .executableTarget(
            name: "kolache",
            dependencies: [
                "KolacheCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/KolacheCLI",
            plugins: [
                .plugin(name: "VersionPlugin", package: "swift-version-plugin"),
            ]
        ),
        .testTarget(
            name: "KolacheCoreTests",
            dependencies: ["KolacheCore"]
        ),
    ]
)
