import Foundation

public enum XcodeGenRunner {
    /// Verify xcodegen is installed, installing Homebrew and/or xcodegen if needed.
    public static func verifyOrInstall() throws {
        if which("xcodegen") != nil { return }

        // Need xcodegen — check for Homebrew first
        if which("brew") == nil {
            try installHomebrew()
        }

        try installXcodeGen()
    }

    /// Run xcodegen generate in the given directory.
    /// Expects a project.yml to already exist there.
    public static func generate(at directory: URL) throws {
        print("  → xcodegen generate")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["xcodegen", "generate"]
        process.currentDirectoryURL = directory

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw KolacheError.xcodeGenFailed(output)
        }
    }

    // MARK: - Private

    private static func installHomebrew() throws {
        print("⚙️  Homebrew not found — installing...")
        print("   You may be prompted for your password.")
        print("")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            "-c",
            #"/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)""#
        ]
        // Pass through to terminal so interactive prompts work
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError
        process.standardInput = FileHandle.standardInput

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw KolacheError.installFailed("Homebrew")
        }

        // After Apple Silicon installs, Homebrew lands in /opt/homebrew/bin
        // which may not be in PATH yet for this process. Add it.
        let env = ProcessInfo.processInfo.environment
        if let path = env["PATH"], !path.contains("/opt/homebrew/bin") {
            setenv("PATH", "/opt/homebrew/bin:/usr/local/bin:\(path)", 1)
        }

        print("")
        print("✅ Homebrew installed.")
    }

    private static func installXcodeGen() throws {
        print("⚙️  xcodegen not found — installing via Homebrew...")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["brew", "install", "xcodegen"]
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw KolacheError.installFailed("xcodegen")
        }

        print("✅ xcodegen installed.")
        print("")
    }

    public static func which(_ command: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try? process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return nil }
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return output?.isEmpty == false ? output : nil
    }
}
