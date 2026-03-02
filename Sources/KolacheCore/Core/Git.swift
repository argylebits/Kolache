import Foundation

public enum Git {
    @discardableResult
    public static func run(_ args: [String], at url: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = url

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw KolacheError.shellCommandFailed("git \(args.joined(separator: " "))", process.terminationStatus)
        }
        return output
    }

    public static func initialize(at url: URL) throws {
        try run(["init"], at: url)
        try run(["add", "."], at: url)
        try run(["commit", "-m", "Initial commit"], at: url)
    }

    /// Returns true if the given directory is already inside a git repository.
    public static func isInsideRepo(at url: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "--is-inside-work-tree"]
        process.currentDirectoryURL = url
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
