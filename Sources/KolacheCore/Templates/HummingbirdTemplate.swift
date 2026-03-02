import Foundation

/// Generates source and test files for a Hummingbird server target.
/// Does NOT generate Package.swift or README — PackageSwiftGenerator handles Package.swift,
/// and Init.swift handles README.
public struct HummingbirdTemplate {
    public let targetName: String
    public let projectDir: URL
    public let config: KolacheConfig

    public init(targetName: String, projectDir: URL, config: KolacheConfig) {
        self.targetName = targetName
        self.projectDir = projectDir
        self.config = config
    }

    public func generate() throws {
        let fm = FileManager.default

        let sourcesDir = projectDir.appendingPathComponent("Sources/\(targetName)")
        let testsDir = projectDir.appendingPathComponent("Tests/\(targetName)Tests")

        try fm.createDirectory(at: sourcesDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: testsDir, withIntermediateDirectories: true)

        try appSwift.write(
            to: sourcesDir.appendingPathComponent("App.swift"),
            atomically: true, encoding: .utf8
        )
        try appBuildSwift.write(
            to: sourcesDir.appendingPathComponent("App+build.swift"),
            atomically: true, encoding: .utf8
        )
        try testsSwift.write(
            to: testsDir.appendingPathComponent("\(targetName)Tests.swift"),
            atomically: true, encoding: .utf8
        )
    }

    // MARK: - File Contents

    private var appSwift: String {
        """
        //  App.swift
        //  \(targetName)
        //
        //  Created by \(config.orgName)

        import Configuration
        import Hummingbird
        import Logging

        @main
        struct App {
            static func main() async throws {
                // Configuration: CLI args > env vars > .env file > defaults
                let reader = try await ConfigReader(providers: [
                    CommandLineArgumentsProvider(),
                    EnvironmentVariablesProvider(),
                    EnvironmentVariablesProvider(environmentFilePath: ".env", allowMissing: true),
                    InMemoryProvider(values: [
                        "http.serverName": "\(targetName)",
                    ]),
                ])
                let app = try await buildApplication(reader: reader)
                try await app.runService()
            }
        }
        """
    }

    private var appBuildSwift: String {
        """
        //  App+build.swift
        //  \(targetName)
        //
        //  Created by \(config.orgName)

        import Configuration
        import Hummingbird
        import Logging

        typealias AppRequestContext = BasicRequestContext

        /// Build application
        /// - Parameter reader: configuration reader
        func buildApplication(reader: ConfigReader) async throws -> some ApplicationProtocol {
            let logger = {
                var logger = Logger(label: "\(targetName)")
                logger.logLevel = reader.string(forKey: "log.level", as: Logger.Level.self, default: .info)
                return logger
            }()
            let router = try buildRouter()
            let app = Application(
                router: router,
                configuration: ApplicationConfiguration(reader: reader.scoped(to: "http")),
                logger: logger
            )
            return app
        }

        /// Build router
        func buildRouter() throws -> Router<AppRequestContext> {
            let router = Router(context: AppRequestContext.self)
            router.addMiddleware {
                LogRequestsMiddleware(.info)
            }
            router.get("/") { _, _ in
                "Hello!"
            }
            return router
        }
        """
    }

    private var testsSwift: String {
        """
        import Configuration
        import Hummingbird
        import HummingbirdTesting
        import Testing

        @testable import \(targetName)

        private let reader = ConfigReader(providers: [
            InMemoryProvider(values: [
                "host": "127.0.0.1",
                "port": "0",
                "log.level": "trace",
            ]),
        ])

        @Suite
        struct \(targetName)Tests {
            @Test("GET / returns Hello!")
            func rootRoute() async throws {
                let app = try await buildApplication(reader: reader)
                try await app.test(.router) { client in
                    try await client.execute(uri: "/", method: .get) { response in
                        #expect(response.body == ByteBuffer(string: "Hello!"))
                    }
                }
            }
        }
        """
    }
}
