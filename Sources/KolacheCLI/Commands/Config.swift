import ArgumentParser
import Foundation
import KolacheCore

struct Config: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "View or edit kolache global configuration."
    )

    @Flag(name: .customLong("reset"), help: "Reset configuration and prompt for new values.")
    var reset: Bool = false

    func run() throws {
        if reset {
            try? FileManager.default.removeItem(at: KolacheConfig.configURL)
        }

        let config = try KolacheConfig.loadOrCreate()

        print("⚙️  kolache configuration (\(KolacheConfig.configURL.path))")
        print("")
        print("  orgName:         \(config.orgName)")
        print("  bundleIdPrefix:  \(config.bundleIdPrefix)")
        print("  templateRepo:    \(config.templateRepo)")
        print("  githubToken:     \(config.githubToken != nil ? "set" : "not set")")
    }
}
