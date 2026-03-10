import Foundation

public enum KolacheError: LocalizedError {
    case projectExists(String)
    case shellCommandFailed(String, Int32)
    case installFailed(String)
    case xcodeGenFailed(String)
    case hummingbirdTemplateFailed(String)
    case packageSwiftNotFound
    case noExecutableTarget

    public var errorDescription: String? {
        switch self {
        case .projectExists(let name):
            return "A directory named \"\(name)\" already exists in the current directory."
        case .shellCommandFailed(let command, let code):
            return "Command failed (\(code)): \(command)"
        case .installFailed(let name):
            return "Failed to install \(name). Please install it manually and try again."
        case .xcodeGenFailed(let output):
            return "xcodegen generate failed:\n\(output)"
        case .hummingbirdTemplateFailed(let output):
            return "Hummingbird template failed:\n\(output)"
        case .packageSwiftNotFound:
            return "No Package.swift found in the current directory."
        case .noExecutableTarget:
            return "No executable target found in Package.swift."
        }
    }
}
