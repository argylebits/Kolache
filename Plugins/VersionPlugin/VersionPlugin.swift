import Foundation
import PackagePlugin

@main
struct VersionPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let outputPath = context.pluginWorkDirectoryURL.appending(path: "Version.swift")

        return [
            .buildCommand(
                displayName: "Generate Version.swift from git tag",
                executable: try context.tool(named: "VersionGen").url,
                arguments: [outputPath.path()],
                outputFiles: [outputPath]
            )
        ]
    }
}
