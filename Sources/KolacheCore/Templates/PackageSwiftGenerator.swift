import Foundation

/// Generates a Package.swift for a single sub-package.
/// In multi-target mode, Init.swift calls this once per sub-package directory,
/// each with its own isolated dependencies and an optional path reference to Core.
public struct PackageSwiftGenerator {
    public let projectName: String
    public let cli: Bool
    public let hummingbird: Bool
    public let package: Bool
    public var corePackageName: String? = nil

    public init(
        projectName: String,
        cli: Bool = false,
        hummingbird: Bool = false,
        package: Bool = false,
        corePackageName: String? = nil
    ) {
        self.projectName = projectName
        self.cli = cli
        self.hummingbird = hummingbird
        self.package = package
        self.corePackageName = corePackageName
    }

    /// Whether the given flags produce multiple targets (auto-creates a Core library).
    /// Any two generation flags trigger multi-target mode.
    public static func isMultiTarget(package: Bool, app: Bool, cli: Bool, hummingbird: Bool) -> Bool {
        [package, app, cli, hummingbird].filter(\.self).count > 1
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
        if cli {
            return cliPackage
        } else if hummingbird {
            return hummingbirdPackage
        } else {
            return libraryPackage
        }
    }

    // MARK: - Library Package.swift

    private var libraryPackage: String {
        var pkgDeps = [String]()
        if let coreName = corePackageName {
            pkgDeps.append("        .package(path: \"../\(coreName)\"),")
        }

        var tgtDeps = [String]()
        if let coreName = corePackageName {
            tgtDeps.append("            dependencies: [\"\(coreName)\"]")
        }

        let depsSection = pkgDeps.isEmpty ? "" : """

                dependencies: [
            \(pkgDeps.joined(separator: "\n"))
                ],
            """

        let targetDepsSection = tgtDeps.isEmpty
            ? "            name: \"\(projectName)\""
            : "            name: \"\(projectName)\",\n\(tgtDeps.joined(separator: "\n"))"

        return """
        // swift-tools-version: 6.2
        import PackageDescription

        let package = Package(
            name: "\(projectName)",
            platforms: [
                .macOS(.v15),
                .iOS(.v18)
            ],
            products: [
                .library(name: "\(projectName)", targets: ["\(projectName)"]),
            ],\(depsSection)
            targets: [
                .target(
        \(targetDepsSection)
                ),
                .testTarget(
                    name: "\(projectName)Tests",
                    dependencies: ["\(projectName)"]
                ),
            ]
        )
        """
    }

    // MARK: - CLI Package.swift

    private var cliPackage: String {
        var pkgDeps = [String]()
        if let coreName = corePackageName {
            pkgDeps.append("        .package(path: \"../\(coreName)\"),")
        }
        pkgDeps.append("        .package(url: \"https://github.com/apple/swift-argument-parser.git\", from: \"1.5.0\"),")

        var tgtDeps = [String]()
        if let coreName = corePackageName {
            tgtDeps.append("                \"\(coreName)\",")
        }
        tgtDeps.append("                .product(name: \"ArgumentParser\", package: \"swift-argument-parser\"),")

        return """
        // swift-tools-version: 6.2
        import PackageDescription

        let package = Package(
            name: "\(projectName)",
            platforms: [
                .macOS(.v15),
            ],
            dependencies: [
        \(pkgDeps.joined(separator: "\n"))
            ],
            targets: [
                .executableTarget(
                    name: "\(projectName)",
                    dependencies: [
        \(tgtDeps.joined(separator: "\n"))
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

    // MARK: - Hummingbird Package.swift

    private var hummingbirdPackage: String {
        var pkgDeps = [String]()
        if let coreName = corePackageName {
            pkgDeps.append("        .package(path: \"../\(coreName)\"),")
        }
        pkgDeps.append("        .package(url: \"https://github.com/hummingbird-project/hummingbird.git\", from: \"2.0.0\"),")
        pkgDeps.append("        .package(url: \"https://github.com/apple/swift-configuration.git\", from: \"1.0.0\", traits: [.defaults, \"CommandLineArguments\"]),")

        var tgtDeps = [String]()
        if let coreName = corePackageName {
            tgtDeps.append("                \"\(coreName)\",")
        }
        tgtDeps.append("                .product(name: \"Configuration\", package: \"swift-configuration\"),")
        tgtDeps.append("                .product(name: \"Hummingbird\", package: \"hummingbird\"),")

        return """
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
        \(pkgDeps.joined(separator: "\n"))
            ],
            targets: [
                .executableTarget(
                    name: "\(projectName)",
                    dependencies: [
        \(tgtDeps.joined(separator: "\n"))
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
}
