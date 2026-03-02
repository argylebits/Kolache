import Foundation

public enum KolacheError: LocalizedError {
    case projectExists(String)
    case shellCommandFailed(String, Int32)
    case missingDependency(name: String, installCommand: String)
    case installFailed(String)
    case xcodeGenFailed(String)
    case invalidFlagCombination(String)
    case configNotFound
    case notAKolacheProject

    public var errorDescription: String? {
        switch self {
        case .projectExists(let name):
            return "A directory named \"\(name)\" already exists in the current directory."
        case .shellCommandFailed(let command, let code):
            return "Command failed (\(code)): \(command)"
        case .missingDependency(let name, let installCommand):
            return """
                \(name) is required but not installed.
                Install it with: \(installCommand)
                """
        case .installFailed(let name):
            return "Failed to install \(name). Please install it manually and try again."
        case .xcodeGenFailed(let output):
            return "xcodegen generate failed:\n\(output)"
        case .invalidFlagCombination(let reason):
            return "Invalid flag combination: \(reason)"
        case .configNotFound:
            return "No kolache config found. Run kolache config to set up."
        case .notAKolacheProject:
            return "No .kolache.json found. This directory was not created by kolache, or you're in the wrong directory."
        }
    }
}
