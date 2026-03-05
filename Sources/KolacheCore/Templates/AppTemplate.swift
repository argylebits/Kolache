import Foundation

/// Generates source files and Xcode project for a SwiftUI app target.
/// Does NOT generate Package.swift or README — PackageSwiftGenerator handles Package.swift,
/// and Init.swift handles README.
public struct AppTemplate {
    public let targetName: String
    public let projectDir: URL
    public let config: KolacheConfig
    public var corePackageName: String? = nil

    public init(targetName: String, projectDir: URL, config: KolacheConfig, corePackageName: String? = nil) {
        self.targetName = targetName
        self.projectDir = projectDir
        self.config = config
        self.corePackageName = corePackageName
    }

    public func generate() throws {
        let fm = FileManager.default

        let sourceDir = projectDir
            .appendingPathComponent(targetName)
        let assetsDir = sourceDir.appendingPathComponent("Assets.xcassets")
        let appIconDir = assetsDir.appendingPathComponent("AppIcon.appiconset")
        let accentDir  = assetsDir.appendingPathComponent("AccentColor.colorset")
        let previewDir = sourceDir.appendingPathComponent("Preview Content")
        let previewAssetsDir = previewDir.appendingPathComponent("Preview Assets.xcassets")

        for dir in [sourceDir, assetsDir, appIconDir, accentDir, previewDir, previewAssetsDir] {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        // Source files
        try appSwift.write(
            to: sourceDir.appendingPathComponent("\(targetName)App.swift"),
            atomically: true, encoding: .utf8
        )
        try contentViewSwift.write(
            to: sourceDir.appendingPathComponent("ContentView.swift"),
            atomically: true, encoding: .utf8
        )

        // Asset catalogs
        try write(assetsContents,       to: assetsDir.appendingPathComponent("Contents.json"))
        try write(appIconContents,      to: appIconDir.appendingPathComponent("Contents.json"))
        try write(accentColorContents,  to: accentDir.appendingPathComponent("Contents.json"))
        try write(previewAssetsContents, to: previewAssetsDir.appendingPathComponent("Contents.json"))

        // project.yml for XcodeGen
        try write(projectYML, to: projectDir.appendingPathComponent("project.yml"))

        // Generate .xcodeproj via XcodeGen
        try XcodeGenRunner.generate(at: projectDir)

        // Remove project.yml — kolache owns the template, not the project
        try fm.removeItem(at: projectDir.appendingPathComponent("project.yml"))
    }

    // MARK: - project.yml

    var projectYML: String {
        let bundleId = "\(config.bundleIdPrefix).\(targetName.lowercased())"

        let localPackagesSection = corePackageName.map { coreName in
            """

            localPackages:
              - ../\(coreName)
            """
        } ?? ""

        let coreDependency = corePackageName.map { coreName in
            """

                dependencies:
                  - package: \(coreName)
            """
        } ?? ""

        return """
        name: \(targetName)

        options:
          bundleIdPrefix: \(config.bundleIdPrefix)
          deploymentTarget:
            iOS: "26.0"
            macOS: "26.0"
          xcodeVersion: "16.0"
          generateEmptyDirectories: true
          createIntermediateGroups: true
        \(localPackagesSection)
        settings:
          base:
            SWIFT_VERSION: 6.2
            MARKETING_VERSION: 1.0
            CURRENT_PROJECT_VERSION: 1
            GENERATE_INFOPLIST_FILE: YES
            ENABLE_USER_SCRIPT_SANDBOXING: YES
            ASSET_CATALOG_COMPILER_OPTIMIZATION: space

        targets:
          \(targetName):
            type: application
            supportedDestinations: [iOS, macOS]
            sources:
              - path: \(targetName)\(coreDependency)
            settings:
              base:
                PRODUCT_BUNDLE_IDENTIFIER: \(bundleId)
                TARGETED_DEVICE_FAMILY: "1,2"
                INFOPLIST_KEY_UIApplicationSceneManifest_Generation: YES
                INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents: YES
                INFOPLIST_KEY_UILaunchScreen_Generation: YES
                INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone: "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
                INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad: "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
                COMBINE_HIDPI_IMAGES: YES
                ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
                ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor

        schemes:
          \(targetName):
            build:
              targets:
                \(targetName): all
            run:
              config: Debug
            test:
              config: Debug
            archive:
              config: Release
        """
    }

    // MARK: - Swift Source Files

    private var appSwift: String {
        """
        //  \(targetName)App.swift
        //  \(targetName)
        //
        //  Created by \(config.orgName)

        import SwiftUI

        @main
        struct \(targetName)App: App {
            var body: some Scene {
                WindowGroup {
                    ContentView()
                }
            }
        }
        """
    }

    private var contentViewSwift: String {
        """
        //  ContentView.swift
        //  \(targetName)
        //
        //  Created by \(config.orgName)

        import SwiftUI

        struct ContentView: View {
            var body: some View {
                VStack {
                    Image(systemName: "globe")
                        .imageScale(.large)
                        .foregroundStyle(.tint)
                    Text("Hello, world!")
                }
                .padding()
            }
        }

        #Preview {
            ContentView()
        }
        """
    }

    // MARK: - Asset Catalog JSON

    private var assetsContents: String {
        """
        {
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }
        """
    }

    private var appIconContents: String {
        """
        {
          "images" : [
            {
              "idiom" : "universal",
              "platform" : "ios",
              "size" : "1024x1024"
            },
            {
              "idiom" : "mac",
              "scale" : "1x",
              "size" : "512x512"
            },
            {
              "idiom" : "mac",
              "scale" : "2x",
              "size" : "512x512"
            }
          ],
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }
        """
    }

    private var accentColorContents: String {
        """
        {
          "colors" : [
            {
              "idiom" : "universal"
            }
          ],
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }
        """
    }

    private var previewAssetsContents: String {
        """
        {
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }
        """
    }

    // MARK: - Helpers

    private func write(_ content: String, to url: URL) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}
