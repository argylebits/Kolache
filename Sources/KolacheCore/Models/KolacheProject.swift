import Foundation

/// Per-project manifest written to .kolache.json at the project root.
/// Records what kolache created so update and migrate know what they own.
public struct KolacheProject: Codable, Sendable {
    public var version: String = "1.0"
    public var projectName: String
    public var flags: [String]
    public var templateRepo: String
    public var templateVersion: String
    public var createdAt: String
    public var managedFiles: [String]

    public static let filename = ".kolache.json"

    public init(
        projectName: String,
        flags: [String],
        templateRepo: String,
        templateVersion: String,
        createdAt: String,
        managedFiles: [String]
    ) {
        self.projectName = projectName
        self.flags = flags
        self.templateRepo = templateRepo
        self.templateVersion = templateVersion
        self.createdAt = createdAt
        self.managedFiles = managedFiles
    }

    public static func load(from directory: URL) throws -> KolacheProject {
        let url = directory.appendingPathComponent(filename)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(KolacheProject.self, from: data)
    }

    public func save(to directory: URL) throws {
        let url = directory.appendingPathComponent(KolacheProject.filename)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url)
    }
}
