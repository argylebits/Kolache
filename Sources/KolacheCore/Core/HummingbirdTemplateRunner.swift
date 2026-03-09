import Foundation

public enum HummingbirdTemplateRunner {
    // TODO: Replace with clone-from-remote once fork is merged upstream
    private static let localTemplatePath =
        NSString("~/Code/ArgyleBits/Forks/Hummingbird/template").expandingTildeInPath

    /// Run the Hummingbird template configure.sh non-interactively.
    public static func run(
        projectDir: URL,
        packageName: String,
        executableName: String
    ) throws {
        let templateDir = URL(fileURLWithPath: localTemplatePath)
        let configureScript = templateDir.appendingPathComponent("configure.sh")

        guard FileManager.default.fileExists(atPath: configureScript.path) else {
            throw KolacheError.hummingbirdTemplateFailed(
                "Hummingbird template not found at \(templateDir.path)"
            )
        }

        print("  → Running Hummingbird template configurator...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            configureScript.path,
            projectDir.path,
            "--package-name", packageName,
            "--executable-name", executableName
        ]
        process.currentDirectoryURL = templateDir
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw KolacheError.hummingbirdTemplateFailed(
                "configure.sh exited with code \(process.terminationStatus)"
            )
        }
    }
}
