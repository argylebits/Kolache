import Foundation

/// Generates source and test files for a plain library target.
/// Does NOT generate Package.swift or README — PackageSwiftGenerator handles Package.swift,
/// and Init.swift handles README.
public struct PackageTemplate {
    public let targetName: String
    public let projectDir: URL

    public init(targetName: String, projectDir: URL) {
        self.targetName = targetName
        self.projectDir = projectDir
    }

    public func generate() throws {
        let fm = FileManager.default

        let sourcesDir = projectDir
            .appendingPathComponent("Sources")
            .appendingPathComponent(targetName)
        let testsDir = projectDir
            .appendingPathComponent("Tests")
            .appendingPathComponent("\(targetName)Tests")

        try fm.createDirectory(at: sourcesDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: testsDir, withIntermediateDirectories: true)

        try mainSwift.write(
            to: sourcesDir.appendingPathComponent("\(targetName).swift"),
            atomically: true, encoding: .utf8
        )
        try testsSwift.write(
            to: testsDir.appendingPathComponent("\(targetName)Tests.swift"),
            atomically: true, encoding: .utf8
        )
    }

    // MARK: - File Contents

    private var mainSwift: String {
        """
        public struct \(targetName) {
            public init() {}
        }
        """
    }

    private var testsSwift: String {
        """
        import Testing
        @testable import \(targetName)

        @Suite("\(targetName) Tests")
        struct \(targetName)Tests {
            @Test("Example test")
            func example() async throws {
                // Add your tests here
            }
        }
        """
    }
}
