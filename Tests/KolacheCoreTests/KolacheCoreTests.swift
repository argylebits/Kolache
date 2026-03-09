import Foundation
import Testing
@testable import KolacheCore

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
        let gen = PackageSwiftGenerator(projectName: "Foo", package: true)
        let dir = try makeTempDir()
        try gen.generate(to: dir)
        let content = try readFile(dir, "Package.swift")

        #expect(content.contains("swift-tools-version: 6.2"))
        #expect(content.contains(#"name: "Foo""#))
        #expect(content.contains(".target("))
        #expect(content.contains(#"name: "FooTests""#))
        #expect(content.contains(#".library(name: "Foo""#))
        #expect(!content.contains(".executableTarget("))
        #expect(!content.contains(".package(path:"))
    }

    @Test("Single --cli generates executable target with ArgumentParser")
    func singleCLI() throws {
        let gen = PackageSwiftGenerator(projectName: "Bar", cli: true)
        let dir = try makeTempDir()
        try gen.generate(to: dir)
        let content = try readFile(dir, "Package.swift")

        #expect(content.contains(".executableTarget("))
        #expect(content.contains("swift-argument-parser"))
        #expect(content.contains(#"name: "Bar""#))
        #expect(content.contains(#"name: "BarTests""#))
        #expect(!content.contains(".package(path:"))
        #expect(!content.contains("hummingbird"))
    }

    @Test("Single --hummingbird generates server target with dependencies")
    func singleHummingbird() throws {
        let gen = PackageSwiftGenerator(projectName: "Srv", hummingbird: true)
        let dir = try makeTempDir()
        try gen.generate(to: dir)
        let content = try readFile(dir, "Package.swift")

        #expect(content.contains(".executableTarget("))
        #expect(content.contains("hummingbird"))
        #expect(content.contains("swift-configuration"))
        #expect(content.contains("HummingbirdTesting"))
        #expect(content.contains(#".tvOS(.v18)"#))
        #expect(!content.contains(".package(path:"))
        #expect(!content.contains("swift-argument-parser"))
    }

    // MARK: - Sub-package output (with corePackageName)

    @Test("CLI with core dep includes path reference and core target dep")
    func cliWithCoreDep() throws {
        let gen = PackageSwiftGenerator(projectName: "BazCLI", cli: true, corePackageName: "BazCore")
        let dir = try makeTempDir()
        try gen.generate(to: dir)
        let content = try readFile(dir, "Package.swift")

        #expect(content.contains(#".package(path: "../BazCore")"#))
        #expect(content.contains(#""BazCore","#))
        #expect(content.contains("swift-argument-parser"))
        #expect(content.contains(#"name: "BazCLI""#))
    }

    @Test("CLI with core dep does NOT include Hummingbird dependencies")
    func cliWithCoreIsolation() throws {
        let gen = PackageSwiftGenerator(projectName: "IsoCLI", cli: true, corePackageName: "IsoCore")
        let dir = try makeTempDir()
        try gen.generate(to: dir)
        let content = try readFile(dir, "Package.swift")

        #expect(!content.contains("hummingbird"))
        #expect(!content.contains("swift-configuration"))
        #expect(!content.contains("HummingbirdTesting"))
    }

    @Test("Hummingbird with core dep includes path reference and core target dep")
    func hummingbirdWithCoreDep() throws {
        let gen = PackageSwiftGenerator(projectName: "BazServer", hummingbird: true, corePackageName: "BazCore")
        let dir = try makeTempDir()
        try gen.generate(to: dir)
        let content = try readFile(dir, "Package.swift")

        #expect(content.contains(#".package(path: "../BazCore")"#))
        #expect(content.contains(#""BazCore","#))
        #expect(content.contains("hummingbird"))
        #expect(content.contains("swift-configuration"))
    }

    @Test("Hummingbird with core dep does NOT include ArgumentParser")
    func hummingbirdWithCoreIsolation() throws {
        let gen = PackageSwiftGenerator(projectName: "IsoServer", hummingbird: true, corePackageName: "IsoCore")
        let dir = try makeTempDir()
        try gen.generate(to: dir)
        let content = try readFile(dir, "Package.swift")

        #expect(!content.contains("swift-argument-parser"))
        #expect(!content.contains("ArgumentParser"))
    }

    @Test("Library with core dep includes path reference")
    func libraryWithCoreDep() throws {
        let gen = PackageSwiftGenerator(projectName: "BazLib", package: true, corePackageName: "BazCore")
        let dir = try makeTempDir()
        try gen.generate(to: dir)
        let content = try readFile(dir, "Package.swift")

        #expect(content.contains(#".package(path: "../BazCore")"#))
        #expect(content.contains(#""BazCore""#))
        #expect(content.contains(".library("))
    }

    @Test("Library without core dep has no path reference or dependencies section")
    func libraryWithoutCoreDep() throws {
        let gen = PackageSwiftGenerator(projectName: "Plain", package: true)
        let dir = try makeTempDir()
        try gen.generate(to: dir)
        let content = try readFile(dir, "Package.swift")

        #expect(!content.contains(".package(path:"))
        #expect(!content.contains("swift-argument-parser"))
        #expect(!content.contains("hummingbird"))
    }

    @Test("Hummingbird without core dep has no path reference")
    func hummingbirdWithoutCoreDep() throws {
        let gen = PackageSwiftGenerator(projectName: "Solo", hummingbird: true)
        let dir = try makeTempDir()
        try gen.generate(to: dir)
        let content = try readFile(dir, "Package.swift")

        #expect(!content.contains(".package(path:"))
        #expect(content.contains("hummingbird"))
    }
}

// MARK: - AppTemplate Tests

@Suite("AppTemplate")
struct AppTemplateTests {
    private static let testConfig = KolacheConfig(orgName: "Test Org", bundleIdPrefix: "com.test")

    @Test("project.yml without core has no localPackages")
    func projectYMLWithoutCore() {
        let template = AppTemplate(
            targetName: "MyApp",
            projectDir: URL(fileURLWithPath: "/tmp"),
            config: Self.testConfig
        )
        let yml = template.projectYML

        #expect(!yml.contains("localPackages"))
        #expect(!yml.contains("dependencies:"))
        #expect(yml.contains("name: MyApp"))
        #expect(yml.contains("path: MyApp"))
    }

    @Test("project.yml with core includes localPackages and target dependency")
    func projectYMLWithCore() {
        let template = AppTemplate(
            targetName: "MyApp",
            projectDir: URL(fileURLWithPath: "/tmp"),
            config: Self.testConfig,
            corePackageName: "MyAppCore"
        )
        let yml = template.projectYML

        #expect(yml.contains("localPackages:"))
        #expect(yml.contains("../MyAppCore"))
        #expect(yml.contains("package: MyAppCore"))
    }

    @Test("Target name is used as-is, no suffix added")
    func targetNameNotSuffixed() {
        let template = AppTemplate(
            targetName: "Pinstripes",
            projectDir: URL(fileURLWithPath: "/tmp"),
            config: Self.testConfig
        )
        let yml = template.projectYML

        #expect(yml.contains("name: Pinstripes"))
        #expect(yml.contains("path: Pinstripes"))
        #expect(!yml.contains("PinstripesApp"))
    }
}

// MARK: - Template Tests

@Suite("Templates")
struct TemplateTests {
    private static let testConfig = KolacheConfig(orgName: "Test Org", bundleIdPrefix: "com.test")

    @Test("PackageTemplate generates source and test files")
    func packageTemplate() throws {
        let dir = try makeTempDir()
        try PackageTemplate(targetName: "MyLib", projectDir: dir, config: Self.testConfig).generate()

        let source = try readFile(dir, "Sources/MyLib/MyLib.swift")
        #expect(source.contains("public struct MyLib"))
        #expect(source.contains("Created by Test Org"))

        let test = try readFile(dir, "Tests/MyLibTests/MyLibTests.swift")
        #expect(test.contains("@testable import MyLib"))
        #expect(test.contains("struct MyLibTests"))
    }

    @Test("CLITemplate generates source with ArgumentParser and test files")
    func cliTemplate() throws {
        let dir = try makeTempDir()
        try CLITemplate(targetName: "MyCLI", projectDir: dir, config: Self.testConfig).generate()

        let source = try readFile(dir, "Sources/MyCLI/MyCLI.swift")
        #expect(source.contains("import ArgumentParser"))
        #expect(source.contains("@main"))
        #expect(source.contains("struct MyCLI: ParsableCommand"))

        let test = try readFile(dir, "Tests/MyCLITests/MyCLITests.swift")
        #expect(test.contains("@testable import MyCLI"))
    }

    @Test("PackageTemplate works for Core naming convention")
    func coreNamingConvention() throws {
        let dir = try makeTempDir()
        try PackageTemplate(targetName: "FooCore", projectDir: dir, config: Self.testConfig).generate()

        let source = try readFile(dir, "Sources/FooCore/FooCore.swift")
        #expect(source.contains("public struct FooCore"))

        let test = try readFile(dir, "Tests/FooCoreTests/FooCoreTests.swift")
        #expect(test.contains("@testable import FooCore"))
    }

    @Test("HummingbirdTemplate generates server files, tests, Dockerfile, and CI")
    func hummingbirdTemplate() throws {
        let dir = try makeTempDir()
        try HummingbirdTemplate(targetName: "MySrv", projectDir: dir, config: Self.testConfig).generate()

        let app = try readFile(dir, "Sources/MySrv/App.swift")
        #expect(app.contains("import Hummingbird"))
        #expect(app.contains("@main"))

        let build = try readFile(dir, "Sources/MySrv/App+build.swift")
        #expect(build.contains("func buildApplication"))
        #expect(build.contains("func buildRouter"))

        let test = try readFile(dir, "Tests/MySrvTests/MySrvTests.swift")
        #expect(test.contains("import HummingbirdTesting"))
        #expect(test.contains(#""http.host": "127.0.0.1""#))
        #expect(test.contains(#""http.port": "0""#))

        let dockerfile = try readFile(dir, "Dockerfile")
        #expect(dockerfile.contains("FROM swift:6.2-noble"))
        #expect(dockerfile.contains("ENTRYPOINT [\"./MySrv\"]"))

        let dockerignore = try readFile(dir, ".dockerignore")
        #expect(dockerignore.contains(".build"))

        let ci = try readFile(dir, ".github/workflows/ci.yml")
        #expect(ci.contains("swift test"))
    }
}

// MARK: - Integration Tests (simulating Init.swift orchestration)

@Suite("Integration — Single Target")
struct SingleTargetIntegrationTests {
    private static let testConfig = KolacheConfig(orgName: "Test Org", bundleIdPrefix: "com.test")

    @Test("Single --package: Package.swift and sources at root, no sub-directories")
    func singlePackage() throws {
        let dir = try makeTempDir()
        try PackageSwiftGenerator(projectName: "MyLib", package: true).generate(to: dir)
        try PackageTemplate(targetName: "MyLib", projectDir: dir, config: Self.testConfig).generate()

        #expect(fileExists(dir, "Package.swift"))
        #expect(fileExists(dir, "Sources/MyLib/MyLib.swift"))
        #expect(fileExists(dir, "Tests/MyLibTests/MyLibTests.swift"))
        #expect(!dirExists(dir, "MyLibCore"))
    }

    @Test("Single --cli: Package.swift and sources at root, no sub-directories")
    func singleCLI() throws {
        let dir = try makeTempDir()
        try PackageSwiftGenerator(projectName: "MyCLI", cli: true).generate(to: dir)
        try CLITemplate(targetName: "MyCLI", projectDir: dir, config: Self.testConfig).generate()

        #expect(fileExists(dir, "Package.swift"))
        #expect(fileExists(dir, "Sources/MyCLI/MyCLI.swift"))
        #expect(fileExists(dir, "Tests/MyCLITests/MyCLITests.swift"))
        #expect(!dirExists(dir, "MyCLICore"))
        #expect(!dirExists(dir, "MyCLICLI"))
    }

    @Test("Single --hummingbird: Package.swift, sources, Dockerfile at root, no sub-directories")
    func singleHummingbird() throws {
        let dir = try makeTempDir()
        try PackageSwiftGenerator(projectName: "MySrv", hummingbird: true).generate(to: dir)
        try HummingbirdTemplate(targetName: "MySrv", projectDir: dir, config: Self.testConfig).generate()

        #expect(fileExists(dir, "Package.swift"))
        #expect(fileExists(dir, "Sources/MySrv/App.swift"))
        #expect(fileExists(dir, "Sources/MySrv/App+build.swift"))
        #expect(fileExists(dir, "Tests/MySrvTests/MySrvTests.swift"))
        #expect(fileExists(dir, "Dockerfile"))
        #expect(fileExists(dir, ".dockerignore"))
        #expect(fileExists(dir, ".github/workflows/ci.yml"))
        #expect(!dirExists(dir, "MySrvCore"))
        #expect(!dirExists(dir, "MySrvServer"))
    }
}

@Suite("Integration — Multi Target")
struct MultiTargetIntegrationTests {
    private static let testConfig = KolacheConfig(orgName: "Test Org", bundleIdPrefix: "com.test")

    @Test("--cli --hummingbird: creates Core, CLI, Server sub-directories")
    func cliHummingbirdStructure() throws {
        let root = try makeTempDir()
        let coreName = "TestCore"
        let cliName = "TestCLI"
        let serverName = "TestServer"

        // Core
        let coreDir = root.appendingPathComponent(coreName)
        try FileManager.default.createDirectory(at: coreDir, withIntermediateDirectories: true)
        try PackageSwiftGenerator(projectName: coreName, package: true).generate(to: coreDir)
        try PackageTemplate(targetName: coreName, projectDir: coreDir, config: Self.testConfig).generate()

        // CLI
        let cliDir = root.appendingPathComponent(cliName)
        try FileManager.default.createDirectory(at: cliDir, withIntermediateDirectories: true)
        try PackageSwiftGenerator(projectName: cliName, cli: true, corePackageName: coreName).generate(to: cliDir)
        try CLITemplate(targetName: cliName, projectDir: cliDir, config: Self.testConfig).generate()

        // Server
        let serverDir = root.appendingPathComponent(serverName)
        try FileManager.default.createDirectory(at: serverDir, withIntermediateDirectories: true)
        try PackageSwiftGenerator(projectName: serverName, hummingbird: true, corePackageName: coreName).generate(to: serverDir)
        try HummingbirdTemplate(targetName: serverName, projectDir: serverDir, config: Self.testConfig).generate()

        // Verify structure
        #expect(dirExists(root, coreName))
        #expect(dirExists(root, cliName))
        #expect(dirExists(root, serverName))
        #expect(!fileExists(root, "Package.swift"))
    }

    @Test("--cli --hummingbird: each sub-package has its own Package.swift")
    func separatePackageSwiftFiles() throws {
        let root = try makeTempDir()
        let coreName = "PkgCore"
        let cliName = "PkgCLI"
        let serverName = "PkgServer"

        let coreDir = root.appendingPathComponent(coreName)
        let cliDir = root.appendingPathComponent(cliName)
        let serverDir = root.appendingPathComponent(serverName)
        for d in [coreDir, cliDir, serverDir] {
            try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }

        try PackageSwiftGenerator(projectName: coreName, package: true).generate(to: coreDir)
        try PackageSwiftGenerator(projectName: cliName, cli: true, corePackageName: coreName).generate(to: cliDir)
        try PackageSwiftGenerator(projectName: serverName, hummingbird: true, corePackageName: coreName).generate(to: serverDir)

        #expect(fileExists(coreDir, "Package.swift"))
        #expect(fileExists(cliDir, "Package.swift"))
        #expect(fileExists(serverDir, "Package.swift"))

        let coreContent = try readFile(coreDir, "Package.swift")
        let cliContent = try readFile(cliDir, "Package.swift")
        let serverContent = try readFile(serverDir, "Package.swift")

        #expect(coreContent.contains(#"name: "PkgCore""#))
        #expect(cliContent.contains(#"name: "PkgCLI""#))
        #expect(serverContent.contains(#"name: "PkgServer""#))
    }

    @Test("--cli --hummingbird: CLI has only ArgumentParser, Server has only Hummingbird")
    func dependencyIsolation() throws {
        let root = try makeTempDir()
        let cliDir = root.appendingPathComponent("IsoCLI")
        let serverDir = root.appendingPathComponent("IsoServer")
        for d in [cliDir, serverDir] {
            try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }

        try PackageSwiftGenerator(projectName: "IsoCLI", cli: true, corePackageName: "IsoCore").generate(to: cliDir)
        try PackageSwiftGenerator(projectName: "IsoServer", hummingbird: true, corePackageName: "IsoCore").generate(to: serverDir)

        let cliContent = try readFile(cliDir, "Package.swift")
        #expect(cliContent.contains("swift-argument-parser"))
        #expect(!cliContent.contains("hummingbird"))
        #expect(!cliContent.contains("swift-configuration"))

        let serverContent = try readFile(serverDir, "Package.swift")
        #expect(serverContent.contains("hummingbird"))
        #expect(serverContent.contains("swift-configuration"))
        #expect(!serverContent.contains("swift-argument-parser"))
    }

    @Test("--cli --hummingbird: both sub-packages reference ../Core")
    func corePathReferences() throws {
        let root = try makeTempDir()
        let cliDir = root.appendingPathComponent("RefCLI")
        let serverDir = root.appendingPathComponent("RefServer")
        for d in [cliDir, serverDir] {
            try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }

        try PackageSwiftGenerator(projectName: "RefCLI", cli: true, corePackageName: "RefCore").generate(to: cliDir)
        try PackageSwiftGenerator(projectName: "RefServer", hummingbird: true, corePackageName: "RefCore").generate(to: serverDir)

        let cliContent = try readFile(cliDir, "Package.swift")
        let serverContent = try readFile(serverDir, "Package.swift")

        #expect(cliContent.contains(#".package(path: "../RefCore")"#))
        #expect(serverContent.contains(#".package(path: "../RefCore")"#))
    }

    @Test("App sub-package uses project name, not suffixed with App")
    func appUsesProjectName() throws {
        let root = try makeTempDir()
        let projectName = "Pinstripes"
        let coreName = "\(projectName)Core"

        // Simulate multi-target: app sub-dir uses project name
        let appDir = root.appendingPathComponent(projectName)
        try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        let template = AppTemplate(
            targetName: projectName,
            projectDir: appDir,
            config: Self.testConfig,
            corePackageName: coreName
        )

        // Verify the target name in project.yml is "Pinstripes" not "PinstripesApp"
        let yml = template.projectYML
        #expect(yml.contains("name: Pinstripes"))
        #expect(!yml.contains("name: PinstripesApp"))
        #expect(yml.contains("path: Pinstripes"))
        #expect(!yml.contains("PinstripesApp"))

        // Verify the directory is at projectName, not projectNameApp
        #expect(dirExists(root, projectName))
        #expect(!dirExists(root, "\(projectName)App"))
    }

    @Test("--app --cli --hummingbird: all four sub-directories created")
    func allSubPackages() throws {
        let root = try makeTempDir()
        let name = "Full"
        let coreName = "\(name)Core"

        let dirs = [coreName, name, "\(name)CLI", "\(name)Server"]
        for d in dirs {
            let dir = root.appendingPathComponent(d)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        // Core
        let coreDir = root.appendingPathComponent(coreName)
        try PackageSwiftGenerator(projectName: coreName, package: true).generate(to: coreDir)
        try PackageTemplate(targetName: coreName, projectDir: coreDir, config: Self.testConfig).generate()

        // CLI
        let cliDir = root.appendingPathComponent("\(name)CLI")
        try PackageSwiftGenerator(projectName: "\(name)CLI", cli: true, corePackageName: coreName).generate(to: cliDir)
        try CLITemplate(targetName: "\(name)CLI", projectDir: cliDir, config: Self.testConfig).generate()

        // Server
        let serverDir = root.appendingPathComponent("\(name)Server")
        try PackageSwiftGenerator(projectName: "\(name)Server", hummingbird: true, corePackageName: coreName).generate(to: serverDir)
        try HummingbirdTemplate(targetName: "\(name)Server", projectDir: serverDir, config: Self.testConfig).generate()

        // Verify all sub-dirs exist with expected files
        #expect(fileExists(coreDir, "Package.swift"))
        #expect(fileExists(coreDir, "Sources/FullCore/FullCore.swift"))
        #expect(fileExists(cliDir, "Package.swift"))
        #expect(fileExists(cliDir, "Sources/FullCLI/FullCLI.swift"))
        #expect(fileExists(serverDir, "Package.swift"))
        #expect(fileExists(serverDir, "Sources/FullServer/App.swift"))
        #expect(fileExists(serverDir, "Dockerfile"))
    }

    @Test("--cli --hummingbird without --package: no Core sub-directory")
    func noPackageNoCoreDir() throws {
        let root = try makeTempDir()
        let cliName = "NoCLI"
        let serverName = "NoServer"

        // CLI (no corePackageName)
        let cliDir = root.appendingPathComponent(cliName)
        try FileManager.default.createDirectory(at: cliDir, withIntermediateDirectories: true)
        try PackageSwiftGenerator(projectName: cliName, cli: true).generate(to: cliDir)
        try CLITemplate(targetName: cliName, projectDir: cliDir, config: Self.testConfig).generate()

        // Server (no corePackageName)
        let serverDir = root.appendingPathComponent(serverName)
        try FileManager.default.createDirectory(at: serverDir, withIntermediateDirectories: true)
        try PackageSwiftGenerator(projectName: serverName, hummingbird: true).generate(to: serverDir)
        try HummingbirdTemplate(targetName: serverName, projectDir: serverDir, config: Self.testConfig).generate()

        // Verify no Core directory
        #expect(!dirExists(root, "NoCore"))
        #expect(dirExists(root, cliName))
        #expect(dirExists(root, serverName))

        // Verify no core references in Package.swift files
        let cliContent = try readFile(cliDir, "Package.swift")
        let serverContent = try readFile(serverDir, "Package.swift")
        #expect(!cliContent.contains(".package(path:"))
        #expect(!serverContent.contains(".package(path:"))
    }

    @Test("Multi-target has no Package.swift at project root")
    func noRootPackageSwift() throws {
        let root = try makeTempDir()
        let coreDir = root.appendingPathComponent("XCore")
        try FileManager.default.createDirectory(at: coreDir, withIntermediateDirectories: true)

        try PackageSwiftGenerator(projectName: "XCore", package: true).generate(to: coreDir)

        // Package.swift should be in coreDir, NOT in root
        #expect(fileExists(coreDir, "Package.swift"))
        #expect(!fileExists(root, "Package.swift"))
    }
}

// MARK: - Model Tests

@Suite("KolacheProject")
struct KolacheProjectTests {
    @Test("Encodes and saves to disk")
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

        #expect(decoded.projectName == "TestProj")
        #expect(decoded.flags == ["cli", "git"])
        #expect(decoded.version == "1.0")
        #expect(decoded.createdAt == "2026-01-01T00:00:00Z")
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
        let error = KolacheError.projectExists("MyApp")
        #expect(error.errorDescription!.contains("MyApp"))
    }
}

// MARK: - Helpers

private func makeTempDir() throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("kolache-tests-\(UUID().uuidString)")
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
