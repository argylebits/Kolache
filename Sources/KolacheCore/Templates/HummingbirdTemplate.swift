import Foundation

/// Generates source and test files for a Hummingbird server target.
/// Does NOT generate Package.swift or README — PackageSwiftGenerator handles Package.swift,
/// and Init.swift handles README.
public struct HummingbirdTemplate {
    public let targetName: String
    public let projectDir: URL

    public init(targetName: String, projectDir: URL) {
        self.targetName = targetName
        self.projectDir = projectDir
    }

    public func generate() throws {
        let fm = FileManager.default

        let sourcesDir = projectDir.appendingPathComponent("Sources/\(targetName)")
        let testsDir = projectDir.appendingPathComponent("Tests/\(targetName)Tests")
        let githubDir = projectDir.appendingPathComponent(".github/workflows")

        try fm.createDirectory(at: sourcesDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: testsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: githubDir, withIntermediateDirectories: true)

        // Source files
        try appSwift.write(
            to: sourcesDir.appendingPathComponent("App.swift"),
            atomically: true, encoding: .utf8
        )
        try appBuildSwift.write(
            to: sourcesDir.appendingPathComponent("App+build.swift"),
            atomically: true, encoding: .utf8
        )

        // Tests
        try testsSwift.write(
            to: testsDir.appendingPathComponent("\(targetName)Tests.swift"),
            atomically: true, encoding: .utf8
        )

        // Docker
        try dockerfile.write(
            to: projectDir.appendingPathComponent("Dockerfile"),
            atomically: true, encoding: .utf8
        )
        try dockerignore.write(
            to: projectDir.appendingPathComponent(".dockerignore"),
            atomically: true, encoding: .utf8
        )

        // CI
        try ciYML.write(
            to: githubDir.appendingPathComponent("ci.yml"),
            atomically: true, encoding: .utf8
        )
    }

    // MARK: - Swift Source Files

    private var appSwift: String {
        """
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

    // MARK: - Tests

    private var testsSwift: String {
        """
        import Configuration
        import Hummingbird
        import HummingbirdTesting
        import Testing

        @testable import \(targetName)

        private let reader = ConfigReader(providers: [
            InMemoryProvider(values: [
                "http.host": "127.0.0.1",
                "http.port": "0",
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

    // MARK: - Dockerfile

    private var dockerfile: String {
        """
        # ================================
        # Build image
        # ================================
        FROM swift:6.2-noble AS build

        # Install OS updates
        RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \\
            && apt-get -q update \\
            && apt-get -q dist-upgrade -y \\
            && apt-get install -y libjemalloc-dev \\
            && rm -rf /var/lib/apt/lists/*

        # Set up a build area
        WORKDIR /build

        # First just resolve dependencies.
        # This creates a cached layer that can be reused
        # as long as your Package.swift/Package.resolved
        # files do not change.
        COPY ./Package.* ./
        RUN swift package resolve

        # Copy entire repo into container
        COPY . .

        # Build the application, with optimizations, with static linking, and using jemalloc
        RUN swift build -c release \\
            --static-swift-stdlib \\
            -Xlinker -ljemalloc

        # Switch to the staging area
        WORKDIR /staging

        # Copy main executable to staging area
        RUN cp "$(swift build --package-path /build -c release --show-bin-path)/\(targetName)" ./

        # Copy static swift backtracer binary to staging area
        RUN cp "/usr/libexec/swift/linux/swift-backtrace-static" ./

        # Copy resources bundled by SPM to staging area
        RUN find -L "$(swift build --package-path /build -c release --show-bin-path)/" -regex '.*\\.resources$' -exec cp -Ra {} ./ \\;

        # Copy any resources from the public directory if it exists
        RUN [ -d /build/public ] && { mv /build/public ./public && chmod -R a-w ./public; } || true

        # ================================
        # Run image
        # ================================
        FROM ubuntu:noble

        # Make sure all system packages are up to date, and install only essential packages.
        RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \\
            && apt-get -q update \\
            && apt-get -q dist-upgrade -y \\
            && apt-get -q install -y \\
              libjemalloc2 \\
              ca-certificates \\
              tzdata \\
            && rm -r /var/lib/apt/lists/*

        # Create a hummingbird user and group with /app as its home directory
        RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app hummingbird

        # Switch to the new home directory
        WORKDIR /app

        # Copy built executable and any staged resources from builder
        COPY --from=build --chown=hummingbird:hummingbird /staging /app

        # Provide configuration needed by the built-in crash reporter and some sensible default behaviors.
        ENV SWIFT_BACKTRACE=enable=yes,sanitize=yes,threads=all,images=all,interactive=no,swift-backtrace=./swift-backtrace-static

        # Ensure all further commands run as the hummingbird user
        USER hummingbird:hummingbird

        # Let Docker bind to port 8080
        EXPOSE 8080

        # Start the Hummingbird service when the image is run, default to listening on 8080 in production environment
        ENTRYPOINT ["./\(targetName)"]
        CMD ["--http-host", "0.0.0.0", "--http-port", "8080"]
        """
    }

    // MARK: - .dockerignore

    private var dockerignore: String {
        """
        .build
        .git
        """
    }

    // MARK: - GitHub Actions CI

    private var ciYML: String {
        """
        name: CI

        on:
          push:
            branches:
            - main
            paths:
            - '**.swift'
            - '**.yml'
          pull_request:
          workflow_dispatch:

        jobs:
          linux:
            runs-on: ubuntu-latest
            strategy:
              matrix:
                image:
                  - 'swift:latest'
            container:
              image: ${{ matrix.image }}
            steps:
            - name: Checkout
              uses: actions/checkout@v6
            - name: Test
              run: swift test
        """
    }
}
