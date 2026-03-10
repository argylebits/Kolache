import Foundation

public struct VersionPluginRecipe {
    private static let packageURL = "https://github.com/argylebits/swift-version-plugin.git"
    private static let packageVersion = "1.0.0"
    private static let pluginEntry = ".plugin(name: \"VersionPlugin\", package: \"swift-version-plugin\")"

    public let projectDirectory: URL

    public init(projectDirectory: URL) {
        self.projectDirectory = projectDirectory
    }

    public func apply() throws {
        let packageSwiftURL = projectDirectory.appendingPathComponent("Package.swift")

        guard FileManager.default.fileExists(atPath: packageSwiftURL.path) else {
            throw KolacheError.packageSwiftNotFound
        }

        var content = try String(contentsOf: packageSwiftURL, encoding: .utf8)

        guard content.contains(".executableTarget(") else {
            throw KolacheError.noExecutableTarget
        }

        // Idempotency — already applied
        if content.contains("swift-version-plugin") {
            print("swift-version-plugin is already a dependency.")
            return
        }

        // Add package dependency
        content = try addPackageDependency(content)

        // Add plugin to executable target
        content = try addPluginToExecutableTarget(content)

        try content.write(to: packageSwiftURL, atomically: true, encoding: .utf8)

        print("  → Added swift-version-plugin dependency")
        print("  → Added VersionPlugin to executable target")
        print("")
        print("  Wire the version into your CommandConfiguration:")
        print("    version: \"MyApp v\\(appVersion)\"")
    }

    // MARK: - Private

    private func addPackageDependency(_ content: String) throws -> String {
        var result = content
        let dep = ".package(url: \"\(Self.packageURL)\", from: \"\(Self.packageVersion)\"),"

        // Find the package-level dependencies array
        if let range = result.range(of: "dependencies: [") {
            let insertPoint = range.upperBound
            result.insert(contentsOf: "\n        \(dep)", at: insertPoint)
        } else {
            // No dependencies array — insert one before targets
            if let targetsRange = result.range(of: "    targets:") {
                let depsBlock = """
                    dependencies: [
                        \(dep)
                    ],

                """
                result.insert(contentsOf: depsBlock, at: targetsRange.lowerBound)
            }
        }

        return result
    }

    private func addPluginToExecutableTarget(_ content: String) throws -> String {
        var result = content

        guard let execRange = result.range(of: ".executableTarget(") else {
            throw KolacheError.noExecutableTarget
        }

        let searchStart = execRange.upperBound

        // Check if there's already a plugins array in this target
        // Find the end of the executable target by tracking parentheses
        let targetEnd = findClosingParen(in: result, from: execRange.lowerBound)

        let targetSlice = result[searchStart..<targetEnd]

        if let pluginsRange = targetSlice.range(of: "plugins: [") {
            // Insert into existing plugins array
            let insertPoint = pluginsRange.upperBound
            result.insert(contentsOf: "\n                    \(Self.pluginEntry),", at: insertPoint)
        } else {
            // No plugins array — find the dependencies closing bracket within this target
            if let depsCloseRange = findDependenciesClose(in: result, from: searchStart, before: targetEnd) {
                let insertPoint = depsCloseRange.upperBound
                result.insert(contentsOf: ",\n                plugins: [\n                    \(Self.pluginEntry),\n                ]", at: insertPoint)
            } else {
                // Bare target with no dependencies or plugins
                // e.g. .executableTarget(\n            name: "Foo"\n        )
                // Find the last non-whitespace character before the closing paren
                var lastContent = result.index(before: targetEnd)
                while lastContent > searchStart && result[lastContent].isWhitespace {
                    lastContent = result.index(before: lastContent)
                }
                let insertAfter = result.index(after: lastContent)
                // Detect indentation from the name: line
                let indent = detectIndent(in: result, from: searchStart, before: targetEnd)
                result.insert(contentsOf: ",\n\(indent)plugins: [\n\(indent)    \(Self.pluginEntry),\n\(indent)]", at: insertAfter)
            }
        }

        return result
    }

    private func findClosingParen(in content: String, from start: String.Index) -> String.Index {
        var depth = 0
        var index = start
        var foundOpen = false

        while index < content.endIndex {
            let char = content[index]
            if char == "(" {
                depth += 1
                foundOpen = true
            } else if char == ")" {
                depth -= 1
                if foundOpen && depth == 0 {
                    return index
                }
            }
            index = content.index(after: index)
        }

        return content.endIndex
    }

    private func detectIndent(in content: String, from start: String.Index, before end: String.Index) -> String {
        // Find the "name:" line and return its leading whitespace
        let slice = content[start..<end]
        if let nameRange = slice.range(of: "name:") {
            // Walk backward from name: to find the start of the line
            var lineStart = nameRange.lowerBound
            while lineStart > content.startIndex {
                let prev = content.index(before: lineStart)
                if content[prev] == "\n" { break }
                lineStart = prev
            }
            return String(content[lineStart..<nameRange.lowerBound])
        }
        return "            " // fallback: 12 spaces (3 levels of 4)
    }

    private func findDependenciesClose(in content: String, from start: String.Index, before end: String.Index) -> Range<String.Index>? {
        let slice = content[start..<end]

        guard let depsStart = slice.range(of: "dependencies: [") else {
            return nil
        }

        var depth = 0
        var index = depsStart.upperBound

        while index < end {
            let char = content[index]
            if char == "[" {
                depth += 1
            } else if char == "]" {
                if depth == 0 {
                    let nextIndex = content.index(after: index)
                    return index..<nextIndex
                }
                depth -= 1
            }
            index = content.index(after: index)
        }

        return nil
    }
}
