import ArgumentParser
import Foundation
import KolacheCore

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List available templates from your remote template repository."
    )

    func run() throws {
        let config = try KolacheConfig.load()
        print("📦 Template repository: \(config.templateRepo)")
        print("")
        // TODO: fetch and display manifest from remote repo
        print("⚠️  Remote manifest fetching not yet implemented.")
        print("")
        print("Available locally:")
        print("  --package       Swift library — Package.swift, sources, tests")
        print("  --app           SwiftUI multiplatform app — iOS 26 + macOS 26")
        print("  --cli           CLI executable with ArgumentParser")
        print("  --hummingbird   Hummingbird HTTP server")
    }
}
