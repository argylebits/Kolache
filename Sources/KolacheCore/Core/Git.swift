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

        // Read pipe data before waiting to avoid deadlock if buffer fills
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let output = String(data: data, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw KolacheError.shellCommandFailed("git \(args.joined(separator: " "))", process.terminationStatus)
        }
        return output
    }

    public static func initialize(at url: URL) throws {
        let output = try run(["init"], at: url)
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            print("    \(trimmed)")
        }
    }
}
