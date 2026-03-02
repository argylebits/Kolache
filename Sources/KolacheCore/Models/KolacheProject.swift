import Foundation

/// Per-project manifest written to .kolache.json at the project root.
/// Records what kolache created and which flags were used.
public struct KolacheProject: Codable, Sendable {
    public var version: String = "1.0"
    public var projectName: String
    public var flags: [String]
    public var createdAt: String

    public static let filename = ".kolache.json"

    public init(
        projectName: String,
        flags: [String],
        createdAt: String
    ) {
        self.projectName = projectName
        self.flags = flags
        self.createdAt = createdAt
    }

    public func save(to directory: URL) throws {
        let url = directory.appendingPathComponent(KolacheProject.filename)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url)
    }
}
