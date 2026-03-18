import Foundation

public enum HummingbirdTemplateRunner {
    private static let repoURL = "https://github.com/hummingbird-project/template.git"
    private static let tag = "2.4.0"

    /// Run the Hummingbird template configure.sh non-interactively.
    public static func run(
        projectDir: URL,
        packageName: String,
        executableName: String
    ) throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kolache-hummingbird-\(UUID().uuidString)")

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Clone the template repo at the pinned tag
        print("  → Cloning Hummingbird template...")
        let clone = Process()
        clone.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        clone.arguments = [
            "clone", "--depth", "1", "--branch", tag, repoURL, tempDir.path
        ]
        clone.standardOutput = FileHandle.standardOutput
        clone.standardError = FileHandle.standardError

        try clone.run()
        clone.waitUntilExit()

        guard clone.terminationStatus == 0 else {
            throw KolacheError.hummingbirdTemplateFailed(
                "Failed to clone Hummingbird template (exit code \(clone.terminationStatus))"
            )
        }

        let configureScript = tempDir.appendingPathComponent("configure.sh")

        guard FileManager.default.fileExists(atPath: configureScript.path) else {
            throw KolacheError.hummingbirdTemplateFailed(
                "configure.sh not found in cloned template"
            )
        }

        print("  → Running Hummingbird template configurator...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            configureScript.path,
            projectDir.path,
            "--package-name", packageName,
            "--executable-name", executableName,
            "--defaults"
        ]
        process.currentDirectoryURL = tempDir
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
