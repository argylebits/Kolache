import Foundation

public enum GitIgnore {
    public static func write(to directory: URL) throws {
        let content = """
        # macOS
        .DS_Store

        # Swift Package Manager
        .build/
        .swiftpm/

        # Xcode
        xcuserdata/
        DerivedData/

        # Editors
        .vscode/
        .cursor/

        # Environment
        .env
        .env.local
        """

        let url = directory.appendingPathComponent(".gitignore")
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}
