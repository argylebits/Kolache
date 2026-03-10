import ArgumentParser

struct Recipe: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "recipe",
        abstract: "Apply a recipe to an existing project.",
        subcommands: [
            VersionPluginCommand.self,
        ]
    )
}
