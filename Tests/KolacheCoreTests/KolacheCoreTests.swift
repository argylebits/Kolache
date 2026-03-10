import Foundation
import Testing
@testable import KolacheCore

// MARK: - Test Fixtures

/// Shared test configuration and naming conventions used across all tests.
private enum Fixtures {
    /// Generates consistent names for a project with the given base name.
    struct ProjectNames {
        let base: String
        var core: String { "\(base)Core" }
        var cli: String { "\(base)CLI" }
        var hummingbird: String { "\(base)Hummingbird" }

        init(_ base: String) { self.base = base }
    }

    /// Creates a PackageSwiftGenerator, generates to a temp dir, and returns the Package.swift content.
    static func generatePackageSwift(
        projectName: String,
        cli: Bool = false,
        package: Bool = false,
        corePackageName: String? = nil
    ) throws -> (content: String, dir: URL) {
        let gen = PackageSwiftGenerator(
            projectName: projectName,
            cli: cli,
            package: package,
            corePackageName: corePackageName
        )
        let dir = try makeTempDir()
        try gen.generate(to: dir)
        let content = try readFile(dir, "Package.swift")
        return (content, dir)
    }

    /// Runs HummingbirdTemplateRunner to generate a project and returns the Package.swift content.
    static func generateHummingbirdPackageSwift(
        projectName: String
    ) throws -> (content: String, dir: URL) {
        let dir = try makeTempDir()
        try HummingbirdTemplateRunner.run(
            projectDir: dir,
            packageName: projectName,
            executableName: projectName
        )
        let content = try readFile(dir, "Package.swift")
        return (content, dir)
    }

    /// Writes a .gitignore and returns its content.
    static func generateGitIgnore() throws -> String {
        let dir = try makeTempDir()
        try GitIgnore.write(to: dir)
        return try readFile(dir, ".gitignore")
    }
}

// MARK: - PackageSwiftGenerator Tests

@Suite("PackageSwiftGenerator")
struct PackageSwiftGeneratorTests {

    // MARK: - isMultiTarget

    @Test("Single flag is not multi-target")
    func singleFlagNotMultiTarget() {
        #expect(!PackageSwiftGenerator.isMultiTarget(package: true, app: false, cli: false, hummingbird: false))
        #expect(!PackageSwiftGenerator.isMultiTarget(package: false, app: true, cli: false, hummingbird: false))
        #expect(!PackageSwiftGenerator.isMultiTarget(package: false, app: false, cli: true, hummingbird: false))
        #expect(!PackageSwiftGenerator.isMultiTarget(package: false, app: false, cli: false, hummingbird: true))
    }

    @Test("Two flags triggers multi-target")
    func twoFlagsMultiTarget() {
        #expect(PackageSwiftGenerator.isMultiTarget(package: true, app: false, cli: true, hummingbird: false))
        #expect(PackageSwiftGenerator.isMultiTarget(package: false, app: true, cli: true, hummingbird: false))
        #expect(PackageSwiftGenerator.isMultiTarget(package: false, app: false, cli: true, hummingbird: true))
    }

    @Test("No flags is not multi-target")
    func noFlagsNotMultiTarget() {
        #expect(!PackageSwiftGenerator.isMultiTarget(package: false, app: false, cli: false, hummingbird: false))
    }

    // MARK: - Single-target output

    @Test("Single --package generates library target with product")
    func singlePackage() throws {
        let projectName = "Foo"
        let (content, _) = try Fixtures.generatePackageSwift(projectName: projectName, package: true)

        #expect(content.contains("swift-tools-version: 6.2"))
        #expect(content.contains("name: \"\(projectName)\""))
        #expect(content.contains(".target("))
        #expect(content.contains("name: \"\(projectName)Tests\""))
        #expect(content.contains(".library(name: \"\(projectName)\""))
        #expect(!content.contains(".executableTarget("))
        #expect(!content.contains(".package(path:"))
    }

    @Test("Single --cli generates executable target with ArgumentParser")
    func singleCLI() throws {
        let projectName = "Bar"
        let (content, _) = try Fixtures.generatePackageSwift(projectName: projectName, cli: true)

        #expect(content.contains(".executableTarget("))
        #expect(content.contains("swift-argument-parser"))
        #expect(content.contains("name: \"\(projectName)\""))
        #expect(content.contains("name: \"\(projectName)Tests\""))
        #expect(!content.contains(".package(path:"))
        #expect(!content.contains("hummingbird"))
    }

    @Test("Single --hummingbird generates server target with dependencies via configure.sh")
    func singleHummingbird() throws {
        let projectName = "Srv"
        let (content, _) = try Fixtures.generateHummingbirdPackageSwift(projectName: projectName)

        #expect(content.contains(".executableTarget("))
        #expect(content.contains("hummingbird"))
        #expect(!content.contains(".package(path:"))
        #expect(!content.contains("swift-argument-parser"))
    }

    // MARK: - With core dependency (when --package is also passed)

    @Test("CLI with core dep includes path reference and core target dep")
    func cliWithCoreDep() throws {
        let names = Fixtures.ProjectNames("Baz")
        let (content, _) = try Fixtures.generatePackageSwift(
            projectName: names.cli, cli: true, corePackageName: names.core
        )

        #expect(content.contains(".package(path: \"../\(names.core)\")"))
        #expect(content.contains("\"\(names.core)\","))
        #expect(content.contains("swift-argument-parser"))
        #expect(content.contains("name: \"\(names.cli)\""))
    }

    @Test("CLI with core dep does NOT include Hummingbird dependencies")
    func cliWithCoreIsolation() throws {
        let names = Fixtures.ProjectNames("Iso")
        let (content, _) = try Fixtures.generatePackageSwift(
            projectName: names.cli, cli: true, corePackageName: names.core
        )

        #expect(!content.contains("hummingbird"))
        #expect(!content.contains("swift-configuration"))
        #expect(!content.contains("HummingbirdTesting"))
    }

    @Test("Hummingbird with core dep includes path reference and core target dep")
    func hummingbirdWithCoreDep() throws {
        let names = Fixtures.ProjectNames("Baz")
        let dir = try makeTempDir()
        try HummingbirdTemplateRunner.run(
            projectDir: dir,
            packageName: names.hummingbird,
            executableName: names.hummingbird
        )
        try HummingbirdTemplate.patchPackageSwift(at: dir, corePackageName: names.core)
        let content = try readFile(dir, "Package.swift")

        #expect(content.contains(".package(path: \"../\(names.core)\")"))
        #expect(content.contains("\"\(names.core)\","))
        #expect(content.contains("hummingbird"))
    }

    @Test("Hummingbird with core dep does NOT include ArgumentParser")
    func hummingbirdWithCoreIsolation() throws {
        let names = Fixtures.ProjectNames("Iso")
        let dir = try makeTempDir()
        try HummingbirdTemplateRunner.run(
            projectDir: dir,
            packageName: names.hummingbird,
            executableName: names.hummingbird
        )
        try HummingbirdTemplate.patchPackageSwift(at: dir, corePackageName: names.core)
        let content = try readFile(dir, "Package.swift")

        #expect(!content.contains("swift-argument-parser"))
        #expect(!content.contains("ArgumentParser"))
    }

    @Test("Library with core dep includes path reference")
    func libraryWithCoreDep() throws {
        let projectName = "BazLib"
        let coreName = "BazCore"
        let (content, _) = try Fixtures.generatePackageSwift(
            projectName: projectName, package: true, corePackageName: coreName
        )

        #expect(content.contains(".package(path: \"../\(coreName)\")"))
        #expect(content.contains("\"\(coreName)\""))
        #expect(content.contains(".library("))
    }

    @Test("Library without core dep has no path reference or external dependencies")
    func libraryWithoutCoreDep() throws {
        let (content, _) = try Fixtures.generatePackageSwift(projectName: "Plain", package: true)

        #expect(!content.contains(".package(path:"))
        #expect(!content.contains("swift-argument-parser"))
        #expect(!content.contains("hummingbird"))
    }

    @Test("Hummingbird without core dep has no path reference")
    func hummingbirdWithoutCoreDep() throws {
        let (content, _) = try Fixtures.generateHummingbirdPackageSwift(projectName: "Solo")

        #expect(!content.contains(".package(path:"))
        #expect(content.contains("hummingbird"))
    }
}

// MARK: - AppTemplate Tests

@Suite("AppTemplate")
struct AppTemplateTests {

    @Test("project.yml without core has no localPackages")
    func projectYMLWithoutCore() {
        let targetName = "MyApp"
        let template = AppTemplate(
            targetName: targetName,
            projectDir: URL(fileURLWithPath: "/tmp")
        )
        let yml = template.projectYML

        #expect(yml.contains("name: \(targetName)"))
        #expect(yml.contains("path: \(targetName)"))
        #expect(!yml.contains("localPackages"))
        #expect(!yml.contains("- package:"))
    }

    @Test("project.yml with core includes localPackages and target dependency")
    func projectYMLWithCore() {
        let targetName = "MyApp"
        let coreName = "\(targetName)Core"
        let template = AppTemplate(
            targetName: targetName,
            projectDir: URL(fileURLWithPath: "/tmp"),
            corePackageName: coreName
        )
        let yml = template.projectYML

        #expect(yml.contains("localPackages:"))
        #expect(yml.contains("../\(coreName)"))
        #expect(yml.contains("package: \(coreName)"))
    }

    @Test("project.yml does not include bundleIdPrefix")
    func noBundleIdPrefix() {
        let targetName = "MyApp"
        let template = AppTemplate(
            targetName: targetName,
            projectDir: URL(fileURLWithPath: "/tmp")
        )
        let yml = template.projectYML

        #expect(!yml.contains("bundleIdPrefix"))
        #expect(!yml.contains("PRODUCT_BUNDLE_IDENTIFIER"))
    }

    @Test("Target name is used as-is, no suffix added")
    func targetNameNotSuffixed() {
        let targetName = "Mosaic"
        let template = AppTemplate(
            targetName: targetName,
            projectDir: URL(fileURLWithPath: "/tmp")
        )
        let yml = template.projectYML

        #expect(yml.contains("name: \(targetName)"))
        #expect(yml.contains("path: \(targetName)"))
        #expect(!yml.contains("\(targetName)App"))
    }

    @Test("App template generates ContentView and App entry point")
    func appTemplateSourceFiles() throws {
        let targetName = "TestApp"
        let dir = try makeTempDir()
        try AppTemplate(
            targetName: targetName,
            projectDir: dir
        ).generate()

        let contentView = try readFile(dir, "\(targetName)/ContentView.swift")
        #expect(contentView.contains("struct ContentView"))
        #expect(contentView.contains("import SwiftUI"))

        let appEntry = try readFile(dir, "\(targetName)/\(targetName)App.swift")
        #expect(appEntry.contains("@main"))
        #expect(appEntry.contains("struct \(targetName)App"))
    }
}

// MARK: - Template Tests

@Suite("Templates")
struct TemplateTests {

    @Test("PackageTemplate generates source and test files")
    func packageTemplate() throws {
        let targetName = "MyLib"
        let dir = try makeTempDir()
        try PackageTemplate(targetName: targetName, projectDir: dir).generate()

        let source = try readFile(dir, "Sources/\(targetName)/\(targetName).swift")
        #expect(source.contains("public struct \(targetName)"))
        #expect(!source.contains("Created by"))

        let test = try readFile(dir, "Tests/\(targetName)Tests/\(targetName)Tests.swift")
        #expect(test.contains("@testable import \(targetName)"))
        #expect(test.contains("struct \(targetName)Tests"))
    }

    @Test("CLITemplate generates source with ArgumentParser and test files")
    func cliTemplate() throws {
        let targetName = "MyCLI"
        let dir = try makeTempDir()
        try CLITemplate(targetName: targetName, projectDir: dir).generate()

        let source = try readFile(dir, "Sources/\(targetName)/\(targetName).swift")
        #expect(source.contains("import ArgumentParser"))
        #expect(source.contains("@main"))
        #expect(source.contains("struct \(targetName): ParsableCommand"))

        let test = try readFile(dir, "Tests/\(targetName)Tests/\(targetName)Tests.swift")
        #expect(test.contains("@testable import \(targetName)"))
    }

    @Test("PackageTemplate works for Core naming convention")
    func coreNamingConvention() throws {
        let targetName = "FooCore"
        let dir = try makeTempDir()
        try PackageTemplate(targetName: targetName, projectDir: dir).generate()

        let source = try readFile(dir, "Sources/\(targetName)/\(targetName).swift")
        #expect(source.contains("public struct \(targetName)"))

        let test = try readFile(dir, "Tests/\(targetName)Tests/\(targetName)Tests.swift")
        #expect(test.contains("@testable import \(targetName)"))
    }

    @Test("patchPackageSwift adds core dependency to package and target dependencies")
    func patchWithCore() throws {
        let dir = try makeTempDir()
        let coreName = "MyProjectCore"

        // Write a Package.swift similar to what configure.sh generates
        let original = """
        // swift-tools-version:6.2
        import PackageDescription

        let package = Package(
            name: "MyProjectHummingbird",
            platforms: [.macOS(.v15), .iOS(.v18), .tvOS(.v18)],
            products: [
                .executable(name: "App", targets: ["App"]),
            ],
            dependencies: [
                .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
                .package(url: "https://github.com/apple/swift-configuration.git", from: "1.0.0", traits: [.defaults, "CommandLineArguments"]),
            ],
            targets: [
                .executableTarget(name: "App",
                    dependencies: [
                        .product(name: "Configuration", package: "swift-configuration"),
                        .product(name: "Hummingbird", package: "hummingbird"),
                    ],
                    path: "Sources/App"
                ),
                .testTarget(name: "AppTests",
                    dependencies: [
                        .byName(name: "App"),
                        .product(name: "HummingbirdTesting", package: "hummingbird")
                    ],
                    path: "Tests/AppTests"
                )
            ]
        )
        """
        try original.write(
            to: dir.appendingPathComponent("Package.swift"),
            atomically: true, encoding: .utf8
        )

        try HummingbirdTemplate.patchPackageSwift(at: dir, corePackageName: coreName)

        let patched = try readFile(dir, "Package.swift")
        #expect(patched.contains(".package(path: \"../\(coreName)\")"))
        #expect(patched.contains("\"\(coreName)\","))
    }

    @Test("patchPackageSwift preserves existing dependencies")
    func patchPreservesExisting() throws {
        let dir = try makeTempDir()
        let coreName = "FooCore"

        let original = """
        // swift-tools-version:6.2
        import PackageDescription

        let package = Package(
            name: "FooHummingbird",
            platforms: [.macOS(.v15), .iOS(.v18), .tvOS(.v18)],
            products: [
                .executable(name: "App", targets: ["App"]),
            ],
            dependencies: [
                .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
                .package(url: "https://github.com/apple/swift-configuration.git", from: "1.0.0", traits: [.defaults, "CommandLineArguments"]),
            ],
            targets: [
                .executableTarget(name: "App",
                    dependencies: [
                        .product(name: "Configuration", package: "swift-configuration"),
                        .product(name: "Hummingbird", package: "hummingbird"),
                    ],
                    path: "Sources/App"
                ),
                .testTarget(name: "AppTests",
                    dependencies: [
                        .byName(name: "App"),
                        .product(name: "HummingbirdTesting", package: "hummingbird")
                    ],
                    path: "Tests/AppTests"
                )
            ]
        )
        """
        try original.write(
            to: dir.appendingPathComponent("Package.swift"),
            atomically: true, encoding: .utf8
        )

        try HummingbirdTemplate.patchPackageSwift(at: dir, corePackageName: coreName)

        let patched = try readFile(dir, "Package.swift")
        #expect(patched.contains("hummingbird-project/hummingbird.git"))
        #expect(patched.contains("swift-configuration"))
        #expect(patched.contains(".product(name: \"Hummingbird\""))
    }

    @Test("patchPackageSwift with Lambda dependencies")
    func patchWithLambda() throws {
        let dir = try makeTempDir()
        let coreName = "BarCore"

        let original = """
        // swift-tools-version:6.2
        import PackageDescription

        let package = Package(
            name: "BarHummingbird",
            platforms: [.macOS(.v15)],
            products: [
                .executable(name: "App", targets: ["App"]),
            ],
            dependencies: [
                .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
                .package(url: "https://github.com/hummingbird-project/hummingbird-lambda.git", from: "2.0.0"),
                .package(url: "https://github.com/apple/swift-configuration.git", from: "1.0.0", traits: [.defaults, "CommandLineArguments"]),
            ],
            targets: [
                .executableTarget(name: "App",
                    dependencies: [
                        .product(name: "Configuration", package: "swift-configuration"),
                        .product(name: "Hummingbird", package: "hummingbird"),
                        .product(name: "HummingbirdLambda", package: "hummingbird-lambda"),
                    ],
                    path: "Sources/App"
                ),
                .testTarget(name: "AppTests",
                    dependencies: [
                        .byName(name: "App"),
                        .product(name: "HummingbirdLambdaTesting", package: "hummingbird-lambda"),
                    ],
                    path: "Tests/AppTests"
                )
            ]
        )
        """
        try original.write(
            to: dir.appendingPathComponent("Package.swift"),
            atomically: true, encoding: .utf8
        )

        try HummingbirdTemplate.patchPackageSwift(at: dir, corePackageName: coreName)

        let patched = try readFile(dir, "Package.swift")
        #expect(patched.contains(".package(path: \"../\(coreName)\")"))
        #expect(patched.contains("\"\(coreName)\","))
        #expect(patched.contains("hummingbird-lambda"))
    }
}

// MARK: - Integration Tests (simulating Init.swift orchestration)

@Suite("Integration — Single Target")
struct SingleTargetIntegrationTests {

    @Test("Single --package: Package.swift and sources at root, no sub-directories")
    func singlePackage() throws {
        let projectName = "MyLib"
        let dir = try makeTempDir()
        try PackageSwiftGenerator(projectName: projectName, package: true).generate(to: dir)
        try PackageTemplate(targetName: projectName, projectDir: dir).generate()

        #expect(fileExists(dir, "Package.swift"))
        #expect(fileExists(dir, "Sources/\(projectName)/\(projectName).swift"))
        #expect(fileExists(dir, "Tests/\(projectName)Tests/\(projectName)Tests.swift"))
        #expect(!dirExists(dir, "\(projectName)Core"))
    }

    @Test("Single --cli: Package.swift and sources at root, no sub-directories")
    func singleCLI() throws {
        let projectName = "MyCLI"
        let dir = try makeTempDir()
        try PackageSwiftGenerator(projectName: projectName, cli: true).generate(to: dir)
        try CLITemplate(targetName: projectName, projectDir: dir).generate()

        #expect(fileExists(dir, "Package.swift"))
        #expect(fileExists(dir, "Sources/\(projectName)/\(projectName).swift"))
        #expect(fileExists(dir, "Tests/\(projectName)Tests/\(projectName)Tests.swift"))
        #expect(!dirExists(dir, "\(projectName)Core"))
        #expect(!dirExists(dir, "\(projectName)CLI"))
    }

    @Test("Single --hummingbird: Package.swift, sources, Dockerfile at root, no sub-directories")
    func singleHummingbird() throws {
        let projectName = "MySrv"
        let dir = try makeTempDir()
        try HummingbirdTemplate(targetName: projectName, projectDir: dir).generate()

        #expect(fileExists(dir, "Package.swift"))
        #expect(fileExists(dir, "Sources/App/App.swift"))
        #expect(fileExists(dir, "Sources/App/App+build.swift"))
        #expect(fileExists(dir, "Tests/AppTests/AppTests.swift"))
        #expect(fileExists(dir, "Dockerfile"))
        #expect(fileExists(dir, ".dockerignore"))
        #expect(fileExists(dir, ".github/workflows/ci.yml"))
        #expect(!dirExists(dir, "\(projectName)Core"))
        #expect(!dirExists(dir, "\(projectName)Hummingbird"))

        let pkg = try readFile(dir, "Package.swift")
        #expect(pkg.contains("name: \"\(projectName)\""))
    }
}

@Suite("Integration — Multi Target with --package")
struct MultiTargetWithPackageTests {

    @Test("--package --cli --hummingbird: creates Core, CLI, Hummingbird sub-directories")
    func structure() throws {
        let names = Fixtures.ProjectNames("Test")
        let root = try makeTempDir()

        let coreDir = root.appendingPathComponent(names.core)
        let cliDir = root.appendingPathComponent(names.cli)
        let hummingbirdDir = root.appendingPathComponent(names.hummingbird)
        for d in [coreDir, cliDir] {
            try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }

        try PackageSwiftGenerator(projectName: names.core, package: true).generate(to: coreDir)
        try PackageTemplate(targetName: names.core, projectDir: coreDir).generate()

        try PackageSwiftGenerator(projectName: names.cli, cli: true, corePackageName: names.core).generate(to: cliDir)
        try CLITemplate(targetName: names.cli, projectDir: cliDir).generate()

        try HummingbirdTemplate(targetName: names.hummingbird, projectDir: hummingbirdDir, corePackageName: names.core).generate()

        #expect(dirExists(root, names.core))
        #expect(dirExists(root, names.cli))
        #expect(dirExists(root, names.hummingbird))
        #expect(!fileExists(root, "Package.swift"))
    }

    @Test("--package --cli --hummingbird: each sub-package has its own Package.swift with correct name")
    func separatePackageSwiftFiles() throws {
        let names = Fixtures.ProjectNames("Pkg")
        let root = try makeTempDir()

        let coreDir = root.appendingPathComponent(names.core)
        let cliDir = root.appendingPathComponent(names.cli)
        let hummingbirdDir = root.appendingPathComponent(names.hummingbird)
        for d in [coreDir, cliDir] {
            try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }

        try PackageSwiftGenerator(projectName: names.core, package: true).generate(to: coreDir)
        try PackageSwiftGenerator(projectName: names.cli, cli: true, corePackageName: names.core).generate(to: cliDir)
        try HummingbirdTemplateRunner.run(projectDir: hummingbirdDir, packageName: names.hummingbird, executableName: names.hummingbird)
        try HummingbirdTemplate.patchPackageSwift(at: hummingbirdDir, corePackageName: names.core)

        #expect(fileExists(coreDir, "Package.swift"))
        #expect(fileExists(cliDir, "Package.swift"))
        #expect(fileExists(hummingbirdDir, "Package.swift"))

        let coreContent = try readFile(coreDir, "Package.swift")
        let cliContent = try readFile(cliDir, "Package.swift")
        let hummingbirdContent = try readFile(hummingbirdDir, "Package.swift")

        #expect(coreContent.contains("name: \"\(names.core)\""))
        #expect(cliContent.contains("name: \"\(names.cli)\""))
        #expect(hummingbirdContent.contains("name: \"\(names.hummingbird)\""))
    }

    @Test("--package --cli --hummingbird: CLI and Hummingbird each depend only on their own deps plus Core")
    func dependencyIsolation() throws {
        let names = Fixtures.ProjectNames("Iso")
        let root = try makeTempDir()
        let cliDir = root.appendingPathComponent(names.cli)
        let hummingbirdDir = root.appendingPathComponent(names.hummingbird)
        try FileManager.default.createDirectory(at: cliDir, withIntermediateDirectories: true)

        try PackageSwiftGenerator(projectName: names.cli, cli: true, corePackageName: names.core).generate(to: cliDir)
        try HummingbirdTemplateRunner.run(projectDir: hummingbirdDir, packageName: names.hummingbird, executableName: names.hummingbird)
        try HummingbirdTemplate.patchPackageSwift(at: hummingbirdDir, corePackageName: names.core)

        let cliContent = try readFile(cliDir, "Package.swift")
        #expect(cliContent.contains("swift-argument-parser"))
        #expect(cliContent.contains("\"\(names.core)\""))
        #expect(!cliContent.contains("hummingbird"))

        let hummingbirdContent = try readFile(hummingbirdDir, "Package.swift")
        #expect(hummingbirdContent.contains("hummingbird"))
        #expect(hummingbirdContent.contains("\"\(names.core)\""))
        #expect(!hummingbirdContent.contains("swift-argument-parser"))
    }

    @Test("--package --cli --hummingbird: both sub-packages reference ../Core")
    func corePathReferences() throws {
        let names = Fixtures.ProjectNames("Ref")
        let root = try makeTempDir()
        let cliDir = root.appendingPathComponent(names.cli)
        let hummingbirdDir = root.appendingPathComponent(names.hummingbird)
        try FileManager.default.createDirectory(at: cliDir, withIntermediateDirectories: true)

        try PackageSwiftGenerator(projectName: names.cli, cli: true, corePackageName: names.core).generate(to: cliDir)
        try HummingbirdTemplateRunner.run(projectDir: hummingbirdDir, packageName: names.hummingbird, executableName: names.hummingbird)
        try HummingbirdTemplate.patchPackageSwift(at: hummingbirdDir, corePackageName: names.core)

        let cliContent = try readFile(cliDir, "Package.swift")
        let hummingbirdContent = try readFile(hummingbirdDir, "Package.swift")

        #expect(cliContent.contains(".package(path: \"../\(names.core)\")"))
        #expect(hummingbirdContent.contains(".package(path: \"../\(names.core)\")"))
    }

    @Test("--package --app: app sub-package uses project name, not suffixed with App")
    func appUsesProjectName() throws {
        let projectName = "Mosaic"
        let names = Fixtures.ProjectNames(projectName)
        let root = try makeTempDir()

        let appDir = root.appendingPathComponent(projectName)
        try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        let template = AppTemplate(
            targetName: projectName,
            projectDir: appDir,
            corePackageName: names.core
        )

        let yml = template.projectYML
        #expect(yml.contains("name: \(projectName)"))
        #expect(!yml.contains("name: \(projectName)App"))
        #expect(yml.contains("path: \(projectName)"))
        #expect(!yml.contains("\(projectName)App"))

        #expect(dirExists(root, projectName))
        #expect(!dirExists(root, "\(projectName)App"))
    }

    @Test("--package --cli --hummingbird: all sub-directories with expected files")
    func allSubPackages() throws {
        let names = Fixtures.ProjectNames("Full")
        let root = try makeTempDir()

        let coreDir = root.appendingPathComponent(names.core)
        let cliDir = root.appendingPathComponent(names.cli)
        let hummingbirdDir = root.appendingPathComponent(names.hummingbird)
        for d in [coreDir, cliDir] {
            try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }

        try PackageSwiftGenerator(projectName: names.core, package: true).generate(to: coreDir)
        try PackageTemplate(targetName: names.core, projectDir: coreDir).generate()

        try PackageSwiftGenerator(projectName: names.cli, cli: true, corePackageName: names.core).generate(to: cliDir)
        try CLITemplate(targetName: names.cli, projectDir: cliDir).generate()

        try HummingbirdTemplate(targetName: names.hummingbird, projectDir: hummingbirdDir, corePackageName: names.core).generate()

        #expect(fileExists(coreDir, "Package.swift"))
        #expect(fileExists(coreDir, "Sources/\(names.core)/\(names.core).swift"))
        #expect(fileExists(cliDir, "Package.swift"))
        #expect(fileExists(cliDir, "Sources/\(names.cli)/\(names.cli).swift"))
        #expect(fileExists(hummingbirdDir, "Package.swift"))
        #expect(fileExists(hummingbirdDir, "Sources/App/App.swift"))
        #expect(fileExists(hummingbirdDir, "Dockerfile"))
    }

    @Test("Multi-target has no Package.swift at project root")
    func noRootPackageSwift() throws {
        let names = Fixtures.ProjectNames("X")
        let root = try makeTempDir()
        let coreDir = root.appendingPathComponent(names.core)
        try FileManager.default.createDirectory(at: coreDir, withIntermediateDirectories: true)

        try PackageSwiftGenerator(projectName: names.core, package: true).generate(to: coreDir)

        #expect(fileExists(coreDir, "Package.swift"))
        #expect(!fileExists(root, "Package.swift"))
    }
}

@Suite("Integration — Multi Target without --package")
struct MultiTargetWithoutPackageTests {

    @Test("--app without --package: app has no local package dependency")
    func appWithoutCoreDep() throws {
        let projectName = "TestApp"
        let root = try makeTempDir()

        let appDir = root.appendingPathComponent(projectName)
        try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        let template = AppTemplate(
            targetName: projectName,
            projectDir: appDir,
            corePackageName: nil
        )
        let yml = template.projectYML

        #expect(yml.contains("name: \(projectName)"))
        #expect(!yml.contains("localPackages:"))
        #expect(!yml.contains("- package:"))
    }

    @Test("--cli --hummingbird without --package: no Core directory or core references")
    func noCoreDirOrReferences() throws {
        let names = Fixtures.ProjectNames("Solo")
        let root = try makeTempDir()

        let cliDir = root.appendingPathComponent(names.cli)
        let hummingbirdDir = root.appendingPathComponent(names.hummingbird)
        try FileManager.default.createDirectory(at: cliDir, withIntermediateDirectories: true)

        try PackageSwiftGenerator(projectName: names.cli, cli: true).generate(to: cliDir)
        try CLITemplate(targetName: names.cli, projectDir: cliDir).generate()

        try HummingbirdTemplate(targetName: names.hummingbird, projectDir: hummingbirdDir).generate()

        // Verify no Core directory
        #expect(!dirExists(root, names.core))
        #expect(dirExists(root, names.cli))
        #expect(dirExists(root, names.hummingbird))

        // Verify no core references in Package.swift files
        let cliContent = try readFile(cliDir, "Package.swift")
        let hummingbirdContent = try readFile(hummingbirdDir, "Package.swift")
        #expect(!cliContent.contains(".package(path:"))
        #expect(!hummingbirdContent.contains(".package(path:"))
        #expect(!cliContent.contains(names.core))
        #expect(!hummingbirdContent.contains(names.core))
    }
}

// MARK: - GitIgnore Tests

@Suite("GitIgnore")
struct GitIgnoreTests {

    @Test(".gitignore includes all expected entries and excludes third-party entries")
    func gitIgnoreContent() throws {
        let content = try Fixtures.generateGitIgnore()

        // Entries Kolache introduces
        #expect(content.contains(".DS_Store"))
        #expect(content.contains(".build/"))
        #expect(content.contains(".swiftpm/"))
        #expect(content.contains("xcuserdata/"))
        #expect(content.contains("DerivedData/"))
        #expect(content.contains(".vscode/"))
        #expect(content.contains(".cursor/"))
        #expect(content.contains(".env"))
        #expect(content.contains(".env.local"))

        // Third-party entries we don't generate
        #expect(!content.contains("Pods/"))
        #expect(!content.contains("Carthage/"))
        #expect(!content.contains("fastlane"))
    }

    @Test(".gitignore is written to the correct location")
    func writesFile() throws {
        let dir = try makeTempDir()
        try GitIgnore.write(to: dir)
        #expect(fileExists(dir, ".gitignore"))
    }
}

// MARK: - Git Tests

@Suite("Git")
struct GitTests {

    @Test("Git.initialize creates a git repository")
    func initializesRepo() throws {
        let dir = try makeTempDir()
        try Git.initialize(at: dir)
        #expect(dirExists(dir, ".git"))
    }

    @Test("Git.initialize does not auto-commit")
    func doesNotAutoCommit() throws {
        let dir = try makeTempDir()

        try "hello".write(
            to: dir.appendingPathComponent("test.txt"),
            atomically: true, encoding: .utf8
        )

        try Git.initialize(at: dir)

        // git log should fail because there are no commits
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["log", "--oneline"]
        process.currentDirectoryURL = dir
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus != 0)
    }

    @Test("Git.initialize does not auto-stage files")
    func doesNotAutoStage() throws {
        let dir = try makeTempDir()

        try "hello".write(
            to: dir.appendingPathComponent("test.txt"),
            atomically: true, encoding: .utf8
        )

        try Git.initialize(at: dir)

        let output = try Git.run(["diff", "--cached", "--name-only"], at: dir)
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmed.isEmpty)
    }

    @Test("Git.run throws on non-zero exit code")
    func throwsOnFailure() throws {
        let dir = try makeTempDir()

        // Running git log in a non-repo directory should fail
        #expect(throws: KolacheError.self) {
            try Git.run(["log"], at: dir)
        }
    }
}

// MARK: - Model Tests

@Suite("KolacheProject")
struct KolacheProjectTests {

    @Test("Encodes and saves to disk with round-trip fidelity")
    func encodesAndSaves() throws {
        let dir = try makeTempDir()
        let project = KolacheProject(
            projectName: "TestProj",
            flags: ["cli", "git"],
            createdAt: "2026-01-01T00:00:00Z"
        )
        try project.save(to: dir)

        let data = try Data(contentsOf: dir.appendingPathComponent(".kolache.json"))
        let decoded = try JSONDecoder().decode(KolacheProject.self, from: data)

        #expect(decoded.projectName == project.projectName)
        #expect(decoded.flags == project.flags)
        #expect(decoded.createdAt == project.createdAt)
        #expect(decoded.version == "1.0")
    }

    @Test("Saves to .kolache.json file")
    func savesCorrectFilename() throws {
        let dir = try makeTempDir()
        let project = KolacheProject(
            projectName: "Test",
            flags: [],
            createdAt: "2026-01-01T00:00:00Z"
        )
        try project.save(to: dir)

        #expect(fileExists(dir, ".kolache.json"))
    }

    @Test("Flags array reflects what was passed")
    func flagsMatchInput() throws {
        let dir = try makeTempDir()
        let flags = ["package", "app", "hummingbird", "cli", "git"]
        let project = KolacheProject(
            projectName: "AllFlags",
            flags: flags,
            createdAt: "2026-01-01T00:00:00Z"
        )
        try project.save(to: dir)

        let data = try Data(contentsOf: dir.appendingPathComponent(".kolache.json"))
        let decoded = try JSONDecoder().decode(KolacheProject.self, from: data)

        #expect(decoded.flags == flags)
        #expect(decoded.flags.count == flags.count)
    }
}

@Suite("ProjectGenerator")
struct ProjectGeneratorTests {

    @Test("Throws projectExists when directory already exists")
    func projectAlreadyExists() throws {
        let projectName = "Existing"
        let root = try makeTempDir()
        let projectDir = root.appendingPathComponent(projectName)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        let generator = ProjectGenerator(
            projectName: projectName,
            baseDirectory: root
        )

        #expect(throws: KolacheError.self) {
            try generator.generate()
        }
    }

    @Test("--force removes existing directory and succeeds")
    func forceRemovesExisting() throws {
        let projectName = "ForceTest"
        let root = try makeTempDir()
        let projectDir = root.appendingPathComponent(projectName)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        try "old".write(to: projectDir.appendingPathComponent("marker.txt"), atomically: true, encoding: .utf8)

        let generator = ProjectGenerator(
            projectName: projectName,
            baseDirectory: root,
            package: true,
            force: true
        )
        try generator.generate()

        #expect(!fileExists(projectDir, "marker.txt"))
        #expect(fileExists(projectDir, "Package.swift"))
    }

    @Test("No flags creates only .kolache.json in project directory")
    func noFlagsOnlyManifest() throws {
        let projectName = "Bare"
        let root = try makeTempDir()

        let generator = ProjectGenerator(
            projectName: projectName,
            baseDirectory: root
        )
        try generator.generate()

        let projectDir = root.appendingPathComponent(projectName)
        #expect(fileExists(projectDir, ".kolache.json"))
        #expect(!fileExists(projectDir, "Package.swift"))
        #expect(!fileExists(projectDir, "README.md"))
        #expect(!dirExists(projectDir, "Sources"))
        #expect(!dirExists(projectDir, ".git"))
    }

    @Test("Single --package generates complete project via ProjectGenerator")
    func singlePackageEndToEnd() throws {
        let projectName = "GenLib"
        let root = try makeTempDir()

        let generator = ProjectGenerator(
            projectName: projectName,
            baseDirectory: root,
            package: true
        )
        try generator.generate()

        let projectDir = root.appendingPathComponent(projectName)
        #expect(fileExists(projectDir, "Package.swift"))
        #expect(fileExists(projectDir, "Sources/\(projectName)/\(projectName).swift"))
        #expect(fileExists(projectDir, "Tests/\(projectName)Tests/\(projectName)Tests.swift"))
        #expect(fileExists(projectDir, "README.md"))
        #expect(fileExists(projectDir, ".kolache.json"))
    }

    @Test("Single --cli generates complete project via ProjectGenerator")
    func singleCLIEndToEnd() throws {
        let projectName = "GenCLI"
        let root = try makeTempDir()

        let generator = ProjectGenerator(
            projectName: projectName,
            baseDirectory: root,
            cli: true
        )
        try generator.generate()

        let projectDir = root.appendingPathComponent(projectName)
        #expect(fileExists(projectDir, "Package.swift"))
        #expect(fileExists(projectDir, "Sources/\(projectName)/\(projectName).swift"))
        #expect(fileExists(projectDir, "README.md"))
        #expect(fileExists(projectDir, ".kolache.json"))
    }

    @Test("Single --hummingbird generates complete project via ProjectGenerator")
    func singleHummingbirdEndToEnd() throws {
        let projectName = "GenSrv"
        let root = try makeTempDir()

        let generator = ProjectGenerator(
            projectName: projectName,
            baseDirectory: root,
            hummingbird: true
        )
        try generator.generate()

        let projectDir = root.appendingPathComponent(projectName)
        #expect(fileExists(projectDir, "Package.swift"))
        #expect(fileExists(projectDir, "Sources/App/App.swift"))
        #expect(fileExists(projectDir, "Dockerfile"))
        #expect(fileExists(projectDir, ".github/workflows/ci.yml"))
        #expect(fileExists(projectDir, "README.md"))
        #expect(fileExists(projectDir, ".kolache.json"))
    }

    @Test("--git creates .git directory and .gitignore")
    func gitFlagCreatesRepo() throws {
        let projectName = "GitTest"
        let root = try makeTempDir()

        let generator = ProjectGenerator(
            projectName: projectName,
            baseDirectory: root,
            package: true,
            git: true
        )
        try generator.generate()

        let projectDir = root.appendingPathComponent(projectName)
        #expect(dirExists(projectDir, ".git"))
        #expect(fileExists(projectDir, ".gitignore"))
    }

    @Test("Multi-target with --package creates Core and wires dependencies")
    func multiTargetWithPackage() throws {
        let names = Fixtures.ProjectNames("Multi")
        let root = try makeTempDir()

        let generator = ProjectGenerator(
            projectName: names.base,
            baseDirectory: root,
            package: true,
            cli: true,
            hummingbird: true
        )
        try generator.generate()

        let projectDir = root.appendingPathComponent(names.base)
        #expect(dirExists(projectDir, names.core))
        #expect(dirExists(projectDir, names.cli))
        #expect(dirExists(projectDir, names.hummingbird))

        let cliPkg = try readFile(projectDir.appendingPathComponent(names.cli), "Package.swift")
        #expect(cliPkg.contains(".package(path: \"../\(names.core)\")"))

        let hummingbirdPkg = try readFile(projectDir.appendingPathComponent(names.hummingbird), "Package.swift")
        #expect(hummingbirdPkg.contains(".package(path: \"../\(names.core)\")"))
    }

    @Test("Multi-target without --package has no Core directory")
    func multiTargetWithoutPackage() throws {
        let names = Fixtures.ProjectNames("NoCore")
        let root = try makeTempDir()

        let generator = ProjectGenerator(
            projectName: names.base,
            baseDirectory: root,
            cli: true,
            hummingbird: true
        )
        try generator.generate()

        let projectDir = root.appendingPathComponent(names.base)
        #expect(!dirExists(projectDir, names.core))
        #expect(dirExists(projectDir, names.cli))
        #expect(dirExists(projectDir, names.hummingbird))
    }

    @Test("Manifest records correct flags")
    func manifestFlags() throws {
        let projectName = "Flagged"
        let root = try makeTempDir()

        let generator = ProjectGenerator(
            projectName: projectName,
            baseDirectory: root,
            package: true,
            cli: true,
            git: true
        )
        try generator.generate()

        let projectDir = root.appendingPathComponent(projectName)
        let data = try Data(contentsOf: projectDir.appendingPathComponent(".kolache.json"))
        let manifest = try JSONDecoder().decode(KolacheProject.self, from: data)

        #expect(manifest.projectName == projectName)
        #expect(manifest.flags.contains("package"))
        #expect(manifest.flags.contains("cli"))
        #expect(manifest.flags.contains("git"))
        #expect(!manifest.flags.contains("app"))
        #expect(!manifest.flags.contains("hummingbird"))
    }
}

@Suite("KolacheError")
struct KolacheErrorTests {

    @Test("Error descriptions are populated")
    func errorDescriptions() {
        let cases: [KolacheError] = [
            .projectExists("Foo"),
            .shellCommandFailed("git status", 1),
            .installFailed("xcodegen"),
            .xcodeGenFailed("error output"),
        ]
        for error in cases {
            #expect(error.errorDescription != nil)
        }
    }

    @Test("projectExists includes project name")
    func projectExistsMessage() {
        let projectName = "MyApp"
        let error = KolacheError.projectExists(projectName)
        #expect(error.errorDescription!.contains(projectName))
    }

    @Test("shellCommandFailed includes command name")
    func shellCommandFailedMessage() {
        let command = "git status"
        let error = KolacheError.shellCommandFailed(command, 1)
        #expect(error.errorDescription!.contains(command))
    }

    @Test("installFailed includes tool name")
    func installFailedMessage() {
        let toolName = "xcodegen"
        let error = KolacheError.installFailed(toolName)
        #expect(error.errorDescription!.contains(toolName))
    }
}

// MARK: - Helpers

/// Shared root for all test temp directories. Cleaned up at the start of each test run.
private let testRoot: URL = {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("kolache-tests")
    try? FileManager.default.removeItem(at: root)
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}()

private func makeTempDir() throws -> URL {
    let dir = testRoot.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

private func readFile(_ dir: URL, _ path: String) throws -> String {
    let url = dir.appendingPathComponent(path)
    return try String(contentsOf: url, encoding: .utf8)
}

private func fileExists(_ dir: URL, _ path: String) -> Bool {
    FileManager.default.fileExists(atPath: dir.appendingPathComponent(path).path)
}

private func dirExists(_ dir: URL, _ path: String) -> Bool {
    var isDir: ObjCBool = false
    return FileManager.default.fileExists(atPath: dir.appendingPathComponent(path).path, isDirectory: &isDir) && isDir.boolValue
}
