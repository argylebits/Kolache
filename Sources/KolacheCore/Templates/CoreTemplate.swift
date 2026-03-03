import Foundation

/// Generates a Core library stub for multi-target projects.
/// Creates source and test files for the <Name>Core library.
public struct CoreTemplate {
    public let targetName: String
    public let projectDir: URL
    public let config: KolacheConfig

    public init(targetName: String, projectDir: URL, config: KolacheConfig) {
        self.targetName = targetName
        self.projectDir = projectDir
        self.config = config
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
        //  \(targetName).swift
        //  \(targetName)
        //
        //  Created by \(config.orgName)

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
