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

    @Test("Single --package generates library target")
    func singlePackage() throws {
        let gen = PackageSwiftGenerator(projectName: "Foo", app: false, cli: false, hummingbird: false, package: true)
        let dir = try makeTempDir()
        try gen.generate(to: dir)
        let content = try readFile(dir, "Package.swift")

        #expect(content.contains("swift-tools-version: 6.2"))
        #expect(content.contains(#"name: "Foo""#))
        #expect(content.contains(".target("))
        #expect(content.contains(#"name: "Foo""#))
        #expect(content.contains(#"name: "FooTests""#))
        #expect(!content.contains(".executableTarget("))
    }

    @Test("Single --cli generates executable target with ArgumentParser")
    func singleCLI() throws {
        let gen = PackageSwiftGenerator(projectName: "Bar", app: false, cli: true, hummingbird: false, package: false)
        let dir = try makeTempDir()
        try gen.generate(to: dir)
        let content = try readFile(dir, "Package.swift")

        #expect(content.contains(".executableTarget("))
        #expect(content.contains("swift-argument-parser"))
        #expect(content.contains(#"name: "Bar""#))
        #expect(content.contains(#"name: "BarTests""#))
    }

    @Test("Single --hummingbird generates server target with dependencies")
    func singleHummingbird() throws {
        let gen = PackageSwiftGenerator(projectName: "Srv", app: false, cli: false, hummingbird: true, package: false)
        let dir = try makeTempDir()
        try gen.generate(to: dir)
        let content = try readFile(dir, "Package.swift")

        #expect(content.contains(".executableTarget("))
        #expect(content.contains("hummingbird"))
        #expect(content.contains("swift-configuration"))
        #expect(content.contains("HummingbirdTesting"))
        #expect(content.contains(#".tvOS(.v18)"#))
    }

    // MARK: - Multi-target output

    @Test("--cli --package generates Core library and CLI target")
    func multiCLIPackage() throws {
        let gen = PackageSwiftGenerator(projectName: "Baz", app: false, cli: true, hummingbird: false, package: true)
        let dir = try makeTempDir()
        try gen.generate(to: dir)
        let content = try readFile(dir, "Package.swift")

        #expect(content.contains(#"name: "BazCore""#))
        #expect(content.contains(#"name: "BazCLI""#))
        #expect(content.contains(#"name: "BazCoreTests""#))
        #expect(content.contains(#"name: "BazCLITests""#))
        #expect(content.contains("swift-argument-parser"))
    }

    @Test("--cli --hummingbird generates Core, CLI, and Server targets with all test targets")
    func multiCLIHummingbird() throws {
        let gen = PackageSwiftGenerator(projectName: "Multi", app: false, cli: true, hummingbird: true, package: false)
        let dir = try makeTempDir()
        try gen.generate(to: dir)
        let content = try readFile(dir, "Package.swift")

        #expect(content.contains(#"name: "MultiCore""#))
        #expect(content.contains(#"name: "MultiCLI""#))
        #expect(content.contains(#"name: "MultiServer""#))
        #expect(content.contains(#"name: "MultiCoreTests""#))
        #expect(content.contains(#"name: "MultiCLITests""#))
        #expect(content.contains(#"name: "MultiServerTests""#))
        #expect(content.contains("HummingbirdTesting"))
    }

    @Test("App target is not included in multi-target Package.swift")
    func multiAppNotInPackageSwift() throws {
        let gen = PackageSwiftGenerator(projectName: "Mix", app: true, cli: true, hummingbird: false, package: false)
        let dir = try makeTempDir()
        try gen.generate(to: dir)
        let content = try readFile(dir, "Package.swift")

        #expect(content.contains(#"name: "MixCore""#))
        #expect(content.contains(#"name: "MixCLI""#))
        #expect(!content.contains(#"name: "MixApp""#))
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

    @Test("CoreTemplate generates source and test files")
    func coreTemplate() throws {
        let dir = try makeTempDir()
        try CoreTemplate(targetName: "FooCore", projectDir: dir, config: Self.testConfig).generate()

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
