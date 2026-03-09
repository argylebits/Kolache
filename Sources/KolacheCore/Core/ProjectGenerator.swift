import Foundation

/// Orchestrates project generation. This is the core logic that `kolache init` delegates to.
public struct ProjectGenerator {
    public let projectName: String
    public let baseDirectory: URL
    public let package: Bool
    public let app: Bool
    public let cli: Bool
    public let hummingbird: Bool
    public let git: Bool
    public let force: Bool

    public init(
        projectName: String,
        baseDirectory: URL,
        package: Bool = false,
        app: Bool = false,
        cli: Bool = false,
        hummingbird: Bool = false,
        git: Bool = false,
        force: Bool = false
    ) {
        self.projectName = projectName
        self.baseDirectory = baseDirectory
        self.package = package
        self.app = app
        self.cli = cli
        self.hummingbird = hummingbird
        self.git = git
        self.force = force
    }

    /// Whether this generates multiple targets.
    public var isMultiTarget: Bool {
        PackageSwiftGenerator.isMultiTarget(package: package, app: app, cli: cli, hummingbird: hummingbird)
    }

    /// Whether any generation flag is set.
    public var hasAnyFlag: Bool {
        package || app || cli || hummingbird
    }

    /// The project directory that will be created.
    public var projectDir: URL {
        baseDirectory.appendingPathComponent(projectName)
    }

    // MARK: - Generate

    public func generate() throws {
        let fm = FileManager.default

        if fm.fileExists(atPath: projectDir.path) {
            if force {
                print("⚠️  --force: Deleting existing \"\(projectName)\" directory...")
                try fm.removeItem(at: projectDir)
            } else {
                throw KolacheError.projectExists(projectName)
            }
        }

        if isMultiTarget {
            print("ℹ️  Multiple flags detected — creating sub-packages.")
        }

        if app {
            try XcodeGenRunner.verifyOrInstall()
        }

        print("📁 Creating \"\(projectName)\"...")
        try fm.createDirectory(at: projectDir, withIntermediateDirectories: true)

        if isMultiTarget {
            try generateMultiTarget()
        } else {
            try generateSingleTarget()
        }

        if hasAnyFlag {
            print("📝 Writing README.md...")
            try writeREADME()
        }

        if git {
            print("📝 Writing .gitignore...")
            try GitIgnore.write(to: projectDir)
        }

        print("📋 Writing .kolache.json...")
        try writeManifest()

        if git {
            print("🗂  Initializing git repository...")
            try Git.initialize(at: projectDir)
        }

        print("")
        print("✅ \(projectName) is ready.")
    }

    // MARK: - Single target generation

    private func generateSingleTarget() throws {
        if app {
            print("🔨 Adding SwiftUI app...")
            try AppTemplate(
                targetName: projectName,
                projectDir: projectDir
            ).generate()
        } else if cli {
            print("📦 Adding CLI package...")
            try PackageSwiftGenerator(projectName: projectName, cli: true)
                .generate(to: projectDir)
            try CLITemplate(
                targetName: projectName,
                projectDir: projectDir
            ).generate()
        } else if hummingbird {
            print("📦 Adding Hummingbird server...")
            try PackageSwiftGenerator(projectName: projectName, hummingbird: true)
                .generate(to: projectDir)
            try HummingbirdTemplate(
                targetName: projectName,
                projectDir: projectDir
            ).generate()
        } else if package {
            print("📦 Adding Swift library...")
            try PackageSwiftGenerator(projectName: projectName, package: true)
                .generate(to: projectDir)
            try PackageTemplate(
                targetName: projectName,
                projectDir: projectDir
            ).generate()
        }
    }

    // MARK: - Multi target generation (sub-packages)

    private func generateMultiTarget() throws {
        let fm = FileManager.default
        var coreName: String? = nil
        var subPackages: [String] = []

        if package {
            let name = "\(projectName)Core"
            coreName = name
            let coreDir = projectDir.appendingPathComponent(name)
            print("📁 Creating \"\(name)\"...")
            try fm.createDirectory(at: coreDir, withIntermediateDirectories: true)
            print("📦 Adding Core package...")
            try PackageSwiftGenerator(projectName: name, package: true)
                .generate(to: coreDir)
            try PackageTemplate(
                targetName: name,
                projectDir: coreDir
            ).generate()
            subPackages.append(name)
        }

        if app {
            let appDir = projectDir.appendingPathComponent(projectName)
            print("📁 Creating \"\(projectName)\"...")
            try fm.createDirectory(at: appDir, withIntermediateDirectories: true)
            print("🔨 Adding Xcode project to \(projectName)...")
            try AppTemplate(
                targetName: projectName,
                projectDir: appDir,
                corePackageName: coreName
            ).generate()
            subPackages.append(projectName)
        }

        if cli {
            let cliName = "\(projectName)CLI"
            let cliDir = projectDir.appendingPathComponent(cliName)
            print("📁 Creating \"\(cliName)\"...")
            try fm.createDirectory(at: cliDir, withIntermediateDirectories: true)
            print("📦 Adding CLI package to \(cliName)...")
            try PackageSwiftGenerator(projectName: cliName, cli: true, corePackageName: coreName)
                .generate(to: cliDir)
            try CLITemplate(
                targetName: cliName,
                projectDir: cliDir
            ).generate()
            subPackages.append(cliName)
        }

        if hummingbird {
            let serverName = "\(projectName)Server"
            let serverDir = projectDir.appendingPathComponent(serverName)
            print("📁 Creating \"\(serverName)\"...")
            try fm.createDirectory(at: serverDir, withIntermediateDirectories: true)
            print("📦 Adding Hummingbird server package to \(serverName)...")
            try PackageSwiftGenerator(projectName: serverName, hummingbird: true, corePackageName: coreName)
                .generate(to: serverDir)
            try HummingbirdTemplate(
                targetName: serverName,
                projectDir: serverDir
            ).generate()
            subPackages.append(serverName)
        }

        print("")
        print("📦 Sub-packages created:")
        for sub in subPackages {
            print("   • \(sub)/")
        }
    }

    // MARK: - README

    private func writeREADME() throws {
        var lines = ["# \(projectName)", ""]

        if isMultiTarget {
            lines.append("A multi-package Swift project.")
            lines.append("")
            lines.append("## Packages")
            lines.append("")
            if package { lines.append("- `\(projectName)Core/` — shared library") }
            if app { lines.append("- `\(projectName)/` — SwiftUI application") }
            if cli { lines.append("- `\(projectName)CLI/` — command-line tool") }
            if hummingbird { lines.append("- `\(projectName)Server/` — Hummingbird HTTP server") }
        } else if app {
            lines.append("A SwiftUI application.")
        } else if cli {
            lines.append("A Swift command-line tool.")
        } else if hummingbird {
            lines.append("A Hummingbird server application.")
        } else {
            lines.append("A Swift package.")
        }

        lines.append("")
        lines.append("## Requirements")
        lines.append("")
        lines.append("- Swift 6.2+")
        lines.append("- macOS 15+")

        let content = lines.joined(separator: "\n")
        try content.write(
            to: projectDir.appendingPathComponent("README.md"),
            atomically: true, encoding: .utf8
        )
    }

    // MARK: - .kolache.json

    private func writeManifest() throws {
        var flags: [String] = []
        if package    { flags.append("package") }
        if app        { flags.append("app") }
        if hummingbird { flags.append("hummingbird") }
        if cli        { flags.append("cli") }
        if git        { flags.append("git") }

        let manifest = KolacheProject(
            projectName: projectName,
            flags: flags,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        try manifest.save(to: projectDir)
    }
}
