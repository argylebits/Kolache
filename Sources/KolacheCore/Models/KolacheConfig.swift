import Foundation

/// Global kolache configuration stored at ~/.kolache/config.json
public struct KolacheConfig: Codable, Sendable {
    public var orgName: String
    public var bundleIdPrefix: String

    public static let configDir = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".kolache")

    public static let configURL = configDir
        .appendingPathComponent("config.json")

    public static func load() throws -> KolacheConfig {
        let data = try Data(contentsOf: configURL)
        return try JSONDecoder().decode(KolacheConfig.self, from: data)
    }

    public func save() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: KolacheConfig.configDir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: KolacheConfig.configURL)
    }

    /// Returns a config if one exists, otherwise prompts the user to create one.
    public static func loadOrCreate() throws -> KolacheConfig {
        if let config = try? load() {
            return config
        }
        return try promptAndCreate()
    }

    private static func promptAndCreate() throws -> KolacheConfig {
        print("👋 Welcome to kolache! Let's set up your configuration.")
        print("")

        print("Organisation name (e.g. Your Name or Company): ", terminator: "")
        let orgName = readLine()?.trimmingCharacters(in: .whitespaces) ?? ""

        print("Bundle ID prefix (e.g. com.yourname): ", terminator: "")
        let bundleIdPrefix = readLine()?.trimmingCharacters(in: .whitespaces) ?? "com.example"

        let config = KolacheConfig(
            orgName: orgName,
            bundleIdPrefix: bundleIdPrefix
        )
        try config.save()

        print("")
        print("✅ Configuration saved to \(configURL.path)")
        print("")

        return config
    }
}
