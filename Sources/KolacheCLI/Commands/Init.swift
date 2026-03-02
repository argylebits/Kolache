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

    /// Number of platform-type flags active.
    private var platformFlagCount: Int {
        [app, cli, hummingbird].filter(\.self).count
    }

    /// Whether this generates multiple targets (auto-creates a Core library).
    private var isMultiTarget: Bool {
        platformFlagCount > 1
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

        // Check xcodegen before doing any work
        if app {
            try XcodeGenRunner.verifyOrInstall()
        }

        // Load or create global config
        let config = try KolacheConfig.loadOrCreate()

        // Always create the directory
        print("📁 Creating \"\(projectName)\"...")
        try fm.createDirectory(at: projectDir, withIntermediateDirectories: true)

        // Generate Package.swift if any flag is set
        if hasAnyFlag {
            print("📝 Writing Package.swift...")
            let generator = PackageSwiftGenerator(
                projectName: projectName,
                app: app,
                cli: cli,
                hummingbird: hummingbird,
                package: package
            )
            try generator.generate(to: projectDir)
        }

        // Generate targets
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
        // Single flag — target name matches project name
        if app {
            print("🔨 Adding SwiftUI app...")
            try AppTemplate(
                targetName: projectName,
                projectDir: projectDir,
                config: config
            ).generate()
        } else if cli {
            print("📦 Adding CLI package...")
            try CLITemplate(
                targetName: projectName,
                projectDir: projectDir,
                config: config
            ).generate()
        } else if hummingbird {
            print("📦 Adding Hummingbird server...")
            try HummingbirdTemplate(
                targetName: projectName,
                projectDir: projectDir,
                config: config
            ).generate()
        } else if package {
            print("📦 Adding Swift library...")
            try PackageTemplate(
                targetName: projectName,
                projectDir: projectDir,
                config: config
            ).generate()
        }
    }

    // MARK: - Multi target generation

    private func generateMultiTarget(projectDir: URL, config: KolacheConfig) throws {
        let coreName = "\(projectName)Core"

        // Core library — always generated in multi-target
        print("📦 Adding \(coreName) library...")
        try CoreTemplate(
            targetName: coreName,
            projectDir: projectDir,
            config: config
        ).generate()

        // Core tests
        let coreTestsDir = projectDir.appendingPathComponent("Tests/\(coreName)Tests")
        try FileManager.default.createDirectory(at: coreTestsDir, withIntermediateDirectories: true)
        let coreTestContent = """
        import Testing
        @testable import \(coreName)

        @Suite("\(coreName) Tests")
        struct \(coreName)Tests {
            @Test("Example test")
            func example() async throws {
                // Add your tests here
            }
        }
        """
        try coreTestContent.write(
            to: coreTestsDir.appendingPathComponent("\(coreName)Tests.swift"),
            atomically: true, encoding: .utf8
        )

        if app {
            let appName = "\(projectName)App"
            print("🔨 Adding \(appName) target...")
            try AppTemplate(
                targetName: appName,
                projectDir: projectDir,
                config: config
            ).generate()
        }

        if cli {
            let cliName = "\(projectName)CLI"
            print("📦 Adding \(cliName) target...")
            try CLITemplate(
                targetName: cliName,
                projectDir: projectDir,
                config: config
            ).generate()
        }

        if hummingbird {
            let serverName = "\(projectName)Server"
            print("📦 Adding \(serverName) target...")
            try HummingbirdTemplate(
                targetName: serverName,
                projectDir: projectDir,
                config: config
            ).generate()
        }
    }

    // MARK: - Next steps

    private func printNextSteps() {
        print("")
        print("   cd \(projectName)")

        if isMultiTarget {
            if app {
                print("   open \(projectName)App.xcodeproj")
            }
            if cli {
                print("   swift run \(projectName)CLI")
            }
            if hummingbird {
                print("   swift run \(projectName)Server")
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
            lines.append("A multi-target Swift project.")
            lines.append("")
            lines.append("## Targets")
            lines.append("")
            lines.append("- **\(projectName)Core** — shared library")
            if app { lines.append("- **\(projectName)App** — SwiftUI application") }
            if cli { lines.append("- **\(projectName)CLI** — command-line tool") }
            if hummingbird { lines.append("- **\(projectName)Server** — Hummingbird HTTP server") }
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
            templateRepo: config.templateRepo,
            templateVersion: "local",
            createdAt: ISO8601DateFormatter().string(from: Date()),
            managedFiles: [
                ".gitignore",
                ".kolache.json",
                "README.md",
            ]
        )
        try manifest.save(to: directory)
    }
}
