import Foundation

/// Generates a composed Package.swift from active flags.
/// Handles single-target vs multi-target naming, dependency composition,
/// and platform declarations.
public struct PackageSwiftGenerator {
    public let projectName: String
    public let app: Bool
    public let cli: Bool
    public let hummingbird: Bool
    public let package: Bool

    public init(projectName: String, app: Bool, cli: Bool, hummingbird: Bool, package: Bool) {
        self.projectName = projectName
        self.app = app
        self.cli = cli
        self.hummingbird = hummingbird
        self.package = package
    }

    /// Whether this generates multiple targets (auto-creates a Core library).
    public var isMultiTarget: Bool {
        [app, cli, hummingbird].filter(\.self).count > 1
    }

    public func generate(to projectDir: URL) throws {
        let content = packageSwift
        try content.write(
            to: projectDir.appendingPathComponent("Package.swift"),
            atomically: true, encoding: .utf8
        )
    }

    // MARK: - Package.swift generation

    private var packageSwift: String {
        if isMultiTarget {
            return multiTargetPackage
        } else {
            return singleTargetPackage
        }
    }

    // MARK: - Single-target Package.swift

    private var singleTargetPackage: String {
        if app {
            return singleAppPackage
        } else if cli {
            return singleCLIPackage
        } else if hummingbird {
            return singleHummingbirdPackage
        } else {
            // --package only (plain library)
            return singleLibraryPackage
        }
    }

    private var singleLibraryPackage: String {
        """
        // swift-tools-version: 6.2
        import PackageDescription

        let package = Package(
            name: "\(projectName)",
            platforms: [
                .macOS(.v15),
                .iOS(.v18)
            ],
            targets: [
                .target(
                    name: "\(projectName)"
                ),
                .testTarget(
                    name: "\(projectName)Tests",
                    dependencies: ["\(projectName)"]
                ),
            ]
        )
        """
    }

    private var singleCLIPackage: String {
        """
        // swift-tools-version: 6.2
        import PackageDescription

        let package = Package(
            name: "\(projectName)",
            platforms: [
                .macOS(.v15),
            ],
            dependencies: [
                .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
            ],
            targets: [
                .executableTarget(
                    name: "\(projectName)",
                    dependencies: [
                        .product(name: "ArgumentParser", package: "swift-argument-parser"),
                    ]
                ),
                .testTarget(
                    name: "\(projectName)Tests",
                    dependencies: ["\(projectName)"]
                ),
            ]
        )
        """
    }

    private var singleAppPackage: String {
        """
        // swift-tools-version: 6.2
        import PackageDescription

        let package = Package(
            name: "\(projectName)",
            platforms: [
                .macOS(.v15),
                .iOS(.v18)
            ],
            targets: [
                .target(
                    name: "\(projectName)"
                ),
            ]
        )
        """
    }

    private var singleHummingbirdPackage: String {
        """
        // swift-tools-version: 6.2
        import PackageDescription

        let package = Package(
            name: "\(projectName)",
            platforms: [
                .macOS(.v15),
                .iOS(.v18),
                .tvOS(.v18),
            ],
            products: [
                .executable(name: "\(projectName)", targets: ["\(projectName)"]),
            ],
            dependencies: [
                .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
                .package(url: "https://github.com/apple/swift-configuration.git", from: "1.0.0", traits: [.defaults, "CommandLineArguments"]),
            ],
            targets: [
                .executableTarget(
                    name: "\(projectName)",
                    dependencies: [
                        .product(name: "Configuration", package: "swift-configuration"),
                        .product(name: "Hummingbird", package: "hummingbird"),
                    ]
                ),
                .testTarget(
                    name: "\(projectName)Tests",
                    dependencies: [
                        .byName(name: "\(projectName)"),
                        .product(name: "HummingbirdTesting", package: "hummingbird"),
                    ]
                ),
            ]
        )
        """
    }

    // MARK: - Multi-target Package.swift

    private var multiTargetPackage: String {
        let coreName = "\(projectName)Core"

        var deps: [String] = []
        var targets: [String] = []

        // Core library target — always present in multi-target
        targets.append("""
                .target(
                    name: "\(coreName)"
                ),
        """)

        // App target
        if app {
            let appName = "\(projectName)App"
            targets.append("""
                    .target(
                        name: "\(appName)",
                        dependencies: ["\(coreName)"]
                    ),
            """)
        }

        // CLI target
        if cli {
            let cliName = "\(projectName)CLI"
            if !deps.contains(where: { $0.contains("swift-argument-parser") }) {
                deps.append("""
                        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
                """)
            }
            targets.append("""
                    .executableTarget(
                        name: "\(cliName)",
                        dependencies: [
                            "\(coreName)",
                            .product(name: "ArgumentParser", package: "swift-argument-parser"),
                        ]
                    ),
            """)
        }

        // Hummingbird target
        if hummingbird {
            let serverName = "\(projectName)Server"
            if !deps.contains(where: { $0.contains("hummingbird") }) {
                deps.append("""
                        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
                """)
                deps.append("""
                        .package(url: "https://github.com/apple/swift-configuration.git", from: "1.0.0", traits: [.defaults, "CommandLineArguments"]),
                """)
            }
            targets.append("""
                    .executableTarget(
                        name: "\(serverName)",
                        dependencies: [
                            "\(coreName)",
                            .product(name: "Configuration", package: "swift-configuration"),
                            .product(name: "Hummingbird", package: "hummingbird"),
                        ]
                    ),
            """)
        }

        // Test targets
        targets.append("""
                .testTarget(
                    name: "\(coreName)Tests",
                    dependencies: ["\(coreName)"]
                ),
        """)

        let depsSection: String
        if deps.isEmpty {
            depsSection = ""
        } else {
            depsSection = """
                dependencies: [
            \(deps.joined(separator: "\n"))
                ],
            """
        }

        let platformSection: String
        if hummingbird {
            platformSection = """
                platforms: [
                    .macOS(.v15),
                    .iOS(.v18),
                    .tvOS(.v18),
                ],
            """
        } else {
            platformSection = """
                platforms: [
                    .macOS(.v15),
                    .iOS(.v18)
                ],
            """
        }

        return """
        // swift-tools-version: 6.2
        import PackageDescription

        let package = Package(
            name: "\(projectName)",
        \(platformSection)
        \(depsSection)    targets: [
        \(targets.joined(separator: "\n"))    ]
        )
        """
    }
}
