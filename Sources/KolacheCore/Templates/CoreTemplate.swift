import Foundation

/// Generates a Core library stub for multi-target projects.
/// Creates Sources/<Name>Core/<Name>Core.swift with a public empty struct.
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

        try fm.createDirectory(at: sourcesDir, withIntermediateDirectories: true)

        try mainSwift.write(
            to: sourcesDir.appendingPathComponent("\(targetName).swift"),
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
}
