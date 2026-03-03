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

    /// Whether the given flags produce multiple targets (auto-creates a Core library).
    /// Any two generation flags trigger multi-target mode.
    public static func isMultiTarget(package: Bool, app: Bool, cli: Bool, hummingbird: Bool) -> Bool {
        [package, app, cli, hummingbird].filter(\.self).count > 1
    }

    public var isMultiTarget: Bool {
        Self.isMultiTarget(package: package, app: app, cli: cli, hummingbird: hummingbird)
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
        if cli {
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

        var lines: [String] = []
        lines.append("// swift-tools-version: 6.2")
        lines.append("import PackageDescription")
        lines.append("")
        lines.append("let package = Package(")
        lines.append("    name: \"\(projectName)\",")

        // Platforms
        if hummingbird {
            lines.append("    platforms: [")
            lines.append("        .macOS(.v15),")
            lines.append("        .iOS(.v18),")
            lines.append("        .tvOS(.v18),")
            lines.append("    ],")
        } else {
            lines.append("    platforms: [")
            lines.append("        .macOS(.v15),")
            lines.append("        .iOS(.v18)")
            lines.append("    ],")
        }

        // Dependencies
        var deps: [String] = []
        if cli {
            deps.append("        .package(url: \"https://github.com/apple/swift-argument-parser.git\", from: \"1.5.0\"),")
        }
        if hummingbird {
            deps.append("        .package(url: \"https://github.com/hummingbird-project/hummingbird.git\", from: \"2.0.0\"),")
            deps.append("        .package(url: \"https://github.com/apple/swift-configuration.git\", from: \"1.0.0\", traits: [.defaults, \"CommandLineArguments\"]),")
        }
        if !deps.isEmpty {
            lines.append("    dependencies: [")
            lines.append(contentsOf: deps)
            lines.append("    ],")
        }

        // Targets
        lines.append("    targets: [")

        // Core library
        lines.append("        .target(")
        lines.append("            name: \"\(coreName)\"")
        lines.append("        ),")

        // CLI target
        if cli {
            let cliName = "\(projectName)CLI"
            lines.append("        .executableTarget(")
            lines.append("            name: \"\(cliName)\",")
            lines.append("            dependencies: [")
            lines.append("                \"\(coreName)\",")
            lines.append("                .product(name: \"ArgumentParser\", package: \"swift-argument-parser\"),")
            lines.append("            ]")
            lines.append("        ),")
        }

        // Hummingbird target
        if hummingbird {
            let serverName = "\(projectName)Server"
            lines.append("        .executableTarget(")
            lines.append("            name: \"\(serverName)\",")
            lines.append("            dependencies: [")
            lines.append("                \"\(coreName)\",")
            lines.append("                .product(name: \"Configuration\", package: \"swift-configuration\"),")
            lines.append("                .product(name: \"Hummingbird\", package: \"hummingbird\"),")
            lines.append("            ]")
            lines.append("        ),")
        }

        // Test targets
        lines.append("        .testTarget(")
        lines.append("            name: \"\(coreName)Tests\",")
        lines.append("            dependencies: [\"\(coreName)\"]")
        lines.append("        ),")

        if cli {
            let cliName = "\(projectName)CLI"
            lines.append("        .testTarget(")
            lines.append("            name: \"\(cliName)Tests\",")
            lines.append("            dependencies: [\"\(cliName)\"]")
            lines.append("        ),")
        }

        if hummingbird {
            let serverName = "\(projectName)Server"
            lines.append("        .testTarget(")
            lines.append("            name: \"\(serverName)Tests\",")
            lines.append("            dependencies: [")
            lines.append("                \"\(serverName)\",")
            lines.append("                .product(name: \"HummingbirdTesting\", package: \"hummingbird\"),")
            lines.append("            ]")
            lines.append("        ),")
        }

        lines.append("    ]")
        lines.append(")")

        return lines.joined(separator: "\n")
    }
}
