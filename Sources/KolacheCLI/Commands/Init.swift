import ArgumentParser
import Foundation
import KolacheCore

struct Init: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Initialize a new project in a new directory."
    )

    @Argument(help: "The name of the project to create.")
    var projectName: String

    @Flag(name: .customLong("package"), help: "Add a plain Swift library (Sources, Tests).")
    var package: Bool = false

    @Flag(name: .customLong("app"), help: "Add a SwiftUI app with Xcode project.")
    var app: Bool = false

    @Flag(name: .customLong("hummingbird"), help: "Add a Hummingbird server target.")
    var hummingbird: Bool = false

    @Flag(name: .customLong("cli"), help: "Add a CLI executable with ArgumentParser.")
    var cli: Bool = false

    @Flag(name: .customLong("git"), help: "Initialize a git repository.")
    var git: Bool = false

    @Flag(name: .customLong("force"), help: "Delete the existing project directory and recreate it from scratch. WARNING: This permanently deletes all files in the directory.")
    var force: Bool = false

    func run() throws {
        let generator = ProjectGenerator(
            projectName: projectName,
            baseDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
            package: package,
            app: app,
            cli: cli,
            hummingbird: hummingbird,
            git: git,
            force: force
        )
        try generator.generate()
        printNextSteps(generator: generator)
    }

    private func printNextSteps(generator: ProjectGenerator) {
        print("")
        print("   cd \(projectName)")

        if generator.isMultiTarget {
            if app {
                print("   open \(projectName)/\(projectName).xcodeproj")
            }
            if cli {
                print("   cd \(projectName)CLI && swift run")
            }
            if hummingbird {
                print("   cd \(projectName)Server && swift run")
            }
        } else {
            if app {
                print("   open \(projectName).xcodeproj")
            } else if cli || hummingbird {
                print("   swift run")
            } else if package {
                print("   swift build")
            }
        }
    }
}
