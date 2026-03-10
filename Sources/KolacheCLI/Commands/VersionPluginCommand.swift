import ArgumentParser
import Foundation
import KolacheCore

struct VersionPluginCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version-plugin",
        abstract: "Add swift-version-plugin to the current project."
    )

    func run() throws {
        let recipe = VersionPluginRecipe(
            projectDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        )
        try recipe.apply()
    }
}
