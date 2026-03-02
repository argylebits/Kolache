import ArgumentParser
import Foundation
import KolacheCore

struct Update: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "update",
        abstract: "Update kolache-managed files in the current project."
    )

    func run() throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        // Verify this is a kolache project
        let project = try KolacheProject.load(from: cwd)

        print("🔄 Updating \(project.projectName)...")
        // TODO: fetch latest templates from remote repo and re-render managed files
        print("⚠️  Remote template fetching not yet implemented.")
        print("    Managed files: \(project.managedFiles.joined(separator: ", "))")
    }
}
