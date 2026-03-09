import ArgumentParser

@main
struct Kolache: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "kolache",
        abstract: "Project scaffolding for Swift developers.",
        discussion: """
            kolache init sets up a project ready to work in — not just ready to compile.
            It handles project structure, non-code resources, AI context files,
            git initialization, and everything SPM and XcodeGen don't cover.
            """,
        subcommands: [
            Init.self,
        ],
        defaultSubcommand: nil
    )
}
