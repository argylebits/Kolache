import ArgumentParser
import Foundation
import KolacheCore

struct Init: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Initialize a new project in a new directory."
    )

    @Argument(help: "The name of the project to create.")
    var projectName: String

    @Flag(name: .customLong("package"), help: "Add a plain Swift library (Sources, Tests).")
    var package: Bool = false

    @Flag(name: .customLong("app"), help: "Add a SwiftUI app with Xcode project.")
    var app: Bool = false

    @Flag(name: .customLong("hummingbird"), help: "Add a Hummingbird server target.")
    var hummingbird: Bool = false

    @Flag(name: .customLong("cli"), help: "Add a CLI executable with ArgumentParser.")
    var cli: Bool = false

    @Flag(name: .customLong("git"), help: "Initialize a git repository with an initial commit.")
    var git: Bool = false

    // MARK: - Computed properties

    /// Whether this generates multiple targets (auto-creates a Core library).
    private var isMultiTarget: Bool {
        PackageSwiftGenerator.isMultiTarget(package: package, app: app, cli: cli, hummingbird: hummingbird)
    }

    /// Whether any generation flag is set.
    private var hasAnyFlag: Bool {
        package || app || cli || hummingbird
    }


    func run() throws {
        let fm = FileManager.default
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        let projectDir = cwd.appendingPathComponent(projectName)

        guard !fm.fileExists(atPath: projectDir.path) else {
            throw KolacheError.projectExists(projectName)
        }

        // Detect if already inside a git repo
        let alreadyInRepo = Git.isInsideRepo(at: cwd)
        let shouldInitGit = git && !alreadyInRepo

        if git && alreadyInRepo {
            print("⚠️  Already inside a git repository — skipping git init.")
        }

        if isMultiTarget && !hasAnyFlag {
            // Multi-target requires at least one generation flag
        }

        // Print notice for auto-detected multi-target
        if isMultiTarget {
            print("ℹ️  Multiple flags detected — creating sub-packages.")
        }

        // Check xcodegen before doing any work
        if app {
            try XcodeGenRunner.verifyOrInstall()
        }

        // Load or create global config
        let config = try KolacheConfig.loadOrCreate()

        // Always create the directory
        print("📁 Creating \"\(projectName)\"...")
        try fm.createDirectory(at: projectDir, withIntermediateDirectories: true)

        // Generate
        if isMultiTarget {
            try generateMultiTarget(projectDir: projectDir, config: config)
        } else {
            try generateSingleTarget(projectDir: projectDir, config: config)
        }

        // README
        if hasAnyFlag {
            print("📝 Writing README.md...")
            try writeREADME(to: projectDir)
        }

        // Git ignore — only for new top-level repos
        if shouldInitGit {
            print("📝 Writing .gitignore...")
            try GitIgnore.write(to: projectDir)
        }

        // Always write .kolache.json
        print("📋 Writing .kolache.json...")
        try writeKolacheProject(to: projectDir, config: config)

        // Git init
        if shouldInitGit {
            print("🗂  Initializing git repository...")
            try Git.initialize(at: projectDir)
        }

        // Done
        print("")
        print("✅ \(projectName) is ready.")
        printNextSteps()
    }

    // MARK: - Single target generation

    private func generateSingleTarget(projectDir: URL, config: KolacheConfig) throws {
        if app {
            print("🔨 Adding SwiftUI app...")
            try AppTemplate(
                targetName: projectName,
                projectDir: projectDir,
                config: config
            ).generate()
        } else if cli {
            print("📦 Adding CLI package...")
            try PackageSwiftGenerator(projectName: projectName, cli: true)
                .generate(to: projectDir)
            try CLITemplate(
                targetName: projectName,
                projectDir: projectDir,
                config: config
            ).generate()
        } else if hummingbird {
            print("📦 Adding Hummingbird server...")
            try PackageSwiftGenerator(projectName: projectName, hummingbird: true)
                .generate(to: projectDir)
            try HummingbirdTemplate(
                targetName: projectName,
                projectDir: projectDir,
                config: config
            ).generate()
        } else if package {
            print("📦 Adding Swift library...")
            try PackageSwiftGenerator(projectName: projectName, package: true)
                .generate(to: projectDir)
            try PackageTemplate(
                targetName: projectName,
                projectDir: projectDir,
                config: config
            ).generate()
        }
    }

    // MARK: - Multi target generation (sub-packages)

    private func generateMultiTarget(projectDir: URL, config: KolacheConfig) throws {
        let fm = FileManager.default
        let coreName = "\(projectName)Core"

        // Core sub-package — always created in multi-target
        let coreDir = projectDir.appendingPathComponent(coreName)
        print("📁 Creating \"\(coreName)\"...")
        try fm.createDirectory(at: coreDir, withIntermediateDirectories: true)
        print("📦 Adding Core package...")
        try PackageSwiftGenerator(projectName: coreName, package: true)
            .generate(to: coreDir)
        try CoreTemplate(
            targetName: coreName,
            projectDir: coreDir,
            config: config
        ).generate()

        var subPackages = [coreName]

        // App sub-package (uses project name, not suffixed)
        if app {
            let appDir = projectDir.appendingPathComponent(projectName)
            print("📁 Creating \"\(projectName)\"...")
            try fm.createDirectory(at: appDir, withIntermediateDirectories: true)
            print("🔨 Adding Xcode project to \(projectName)...")
            try AppTemplate(
                targetName: projectName,
                projectDir: appDir,
                config: config,
                corePackageName: coreName
            ).generate()
            subPackages.append(projectName)
        }

        // CLI sub-package
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
                projectDir: cliDir,
                config: config
            ).generate()
            subPackages.append(cliName)
        }

        // Hummingbird sub-package (named Server)
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
                projectDir: serverDir,
                config: config
            ).generate()
            subPackages.append(serverName)
        }

        print("")
        print("📦 Sub-packages created:")
        for sub in subPackages {
            print("   • \(sub)/")
        }
    }

    // MARK: - Next steps

    private func printNextSteps() {
        print("")
        print("   cd \(projectName)")

        if isMultiTarget {
            if app {
                print("   open \(projectName)/\(projectName).xcodeproj")
            }
            if cli {
                print("   cd \(projectName)CLI && swift run")
            }
            if hummingbird {
                print("   cd \(projectName)Server && swift run")
            }
        } else {
            if app {
                print("   open \(projectName).xcodeproj")
            } else if cli || hummingbird {
                print("   swift run")
            } else if package {
                print("   swift build")
            }
        }
    }

    // MARK: - README

    private func writeREADME(to projectDir: URL) throws {
        var lines = ["# \(projectName)", ""]

        if isMultiTarget {
            lines.append("A multi-package Swift project.")
            lines.append("")
            lines.append("## Packages")
            lines.append("")
            lines.append("- `\(projectName)Core/` — shared library")
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

    private func writeKolacheProject(to directory: URL, config: KolacheConfig) throws {
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
        try manifest.save(to: directory)
    }
}
