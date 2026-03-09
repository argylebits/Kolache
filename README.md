![Kolache](Assets/kolache-icon-256.png)

# Kolache

A Swift CLI for project scaffolding. One command, ready-to-work project.

> A kolache is pastry dough with different fillings. The engine is the dough —
> the templates are the fillings. Same process, different output.

```bash
kolache init MyApp --app --cli --package --git
```

Kolache handles the stuff that `swift package init` and XcodeGen don't —
project structure, conventions, boilerplate, and the non-code resources that
make a project ready to work in rather than just ready to compile.

---

## Install

```bash
swift build -c release
cp .build/release/kolache ~/bin/kolache
```

---

## Usage

### `kolache init <Name> [flags]`

Creates a new project directory with the structure determined by your flags.

---

## Flags

Flags are additive layers. The base command does the minimum. Each flag adds
exactly what it describes. Flags compose freely — combining two or more
automatically creates a multi-package project with isolated dependencies.

### `--package`

Swift library with Sources, Tests, and a `Package.swift`.

When combined with other flags, `--package` creates a shared `<Name>Core/`
library that sibling packages depend on.

```
MyLib/
├── Package.swift
├── Sources/MyLib/
│   └── MyLib.swift
├── Tests/MyLibTests/
│   └── MyLibTests.swift
├── README.md
└── .kolache.json
```

### `--cli`

Executable CLI with [ArgumentParser](https://github.com/apple/swift-argument-parser).

```
MyCLI/
├── Package.swift
├── Sources/MyCLI/
│   └── MyCLI.swift
├── Tests/MyCLITests/
│   └── MyCLITests.swift
├── README.md
└── .kolache.json
```

### `--hummingbird`

[Hummingbird](https://github.com/hummingbird-project/hummingbird) HTTP server
with [swift-configuration](https://github.com/apple/swift-configuration),
Dockerfile, and GitHub Actions CI.

```
MyServer/
├── Package.swift
├── Sources/MyServer/
│   ├── App.swift
│   └── App+build.swift
├── Tests/MyServerTests/
│   └── MyServerTests.swift
├── Dockerfile
├── .dockerignore
├── .github/workflows/ci.yml
├── README.md
└── .kolache.json
```

### `--app`

SwiftUI application with Xcode project generated via
[XcodeGen](https://github.com/yonaskolb/XcodeGen). Multiplatform
(iOS + macOS) with a single target using `supportedDestinations`.

```
MyApp/
├── MyApp.xcodeproj
├── MyApp/
│   ├── MyAppApp.swift
│   ├── ContentView.swift
│   ├── Assets.xcassets/
│   └── Preview Content/
├── README.md
└── .kolache.json
```

No `Package.swift` — the app is Xcode-only. XcodeGen is auto-installed
(via Homebrew) on first use if not present. Team, signing, and bundle ID
are configured in Xcode after opening the project, just like a normal
Xcode project.

### `--git`

Initializes a git repository with a `.gitignore`. Does not stage or commit
files — that's left to you.

### `--force`

Delete the existing project directory and recreate it from scratch.

**WARNING:** This permanently deletes all files in the directory. Use with
caution.

### No flags

Just the directory and `.kolache.json`. No language assumptions.

```
MyProject/
└── .kolache.json
```

---

## Combining Flags

Single flag = flat project at the root. Two or more flags = automatic
multi-package layout where each component gets its own directory, its own
`Package.swift`, and only the dependencies it actually needs.

### Why separate packages?

A single `Package.swift` with multiple targets pulls all dependencies into
the same resolution graph. Your CLI shouldn't need Hummingbird. Your server
shouldn't need ArgumentParser. Separate packages keep dependencies isolated —
each sub-package only imports what it uses.

### How it works

When two or more generation flags are combined, kolache creates a sub-directory
for each flag. If `--package` is included, it also creates a `<Name>Core/`
shared library and wires each sibling package to it via
`path: "../<Name>Core"`.

### Naming

| Flag            | Single-flag name | Multi-flag sub-directory |
|-----------------|------------------|-------------------------|
| `--package`     | `<Name>/`        | `<Name>Core/`           |
| `--cli`         | `<Name>/`        | `<Name>CLI/`            |
| `--hummingbird` | `<Name>/`        | `<Name>Server/`         |
| `--app`         | `<Name>/`        | `<Name>/`               |

The app sub-package keeps the project name (no suffix) since it's the
primary deliverable in most projects.

### Examples

#### `kolache init Pinstripes --app --hummingbird --package --git`

```
Pinstripes/
├── PinstripesCore/
│   ├── Package.swift              ← library, no external deps
│   ├── Sources/PinstripesCore/
│   └── Tests/PinstripesCoreTests/
├── Pinstripes/
│   ├── Pinstripes.xcodeproj       ← references ../PinstripesCore
│   └── Pinstripes/
│       ├── PinstripesApp.swift
│       ├── ContentView.swift
│       └── Assets.xcassets/
├── PinstripesServer/
│   ├── Package.swift              ← Hummingbird + ../PinstripesCore
│   ├── Sources/PinstripesServer/
│   ├── Tests/PinstripesServerTests/
│   ├── Dockerfile
│   └── .github/workflows/ci.yml
├── README.md
├── .gitignore
└── .kolache.json
```

The server's `Package.swift` depends on Hummingbird and Core — nothing else:

```swift
dependencies: [
    .package(path: "../PinstripesCore"),
    .package(url: ".../hummingbird.git", from: "2.0.0"),
    .package(url: ".../swift-configuration.git", from: "1.0.0", ...),
]
```

#### `kolache init Tools --cli --hummingbird`

Without `--package`, no Core library is created. Each sub-package is
independent with its own dependencies:

```
Tools/
├── ToolsCLI/
│   ├── Package.swift              ← ArgumentParser only
│   ├── Sources/ToolsCLI/
│   └── Tests/ToolsCLITests/
├── ToolsServer/
│   ├── Package.swift              ← Hummingbird only
│   ├── Sources/ToolsServer/
│   ├── Tests/ToolsServerTests/
│   └── Dockerfile
├── README.md
└── .kolache.json
```

#### `kolache init Atlas --app --cli --hummingbird --package --git`

All four sub-packages: Core, app, CLI, and server.

```
Atlas/
├── AtlasCore/            ← shared library
├── Atlas/                ← SwiftUI app (depends on Core)
├── AtlasCLI/             ← CLI tool (depends on Core)
├── AtlasServer/          ← Hummingbird server (depends on Core)
├── README.md
├── .gitignore
└── .kolache.json
```

---

## Project Manifest

A `.kolache.json` file is written at the project root on every `kolache init`.
It records the project name, which flags were used, and when it was created.

```json
{
  "version": "1.0",
  "projectName": "Pinstripes",
  "flags": ["package", "app", "hummingbird", "git"],
  "createdAt": "2026-03-02T21:38:07Z"
}
```

---

## Architecture

Kolache is structured as two targets:

```
Kolache/
├── Package.swift
├── Sources/
│   ├── KolacheCore/              ← all logic, templates, models
│   │   ├── Core/
│   │   │   ├── Git.swift
│   │   │   ├── GitIgnore.swift
│   │   │   ├── KolacheError.swift
│   │   │   └── XcodeGenRunner.swift
│   │   ├── Models/
│   │   │   └── KolacheProject.swift
│   │   └── Templates/
│   │       ├── AppTemplate.swift
│   │       ├── CLITemplate.swift
│   │       ├── HummingbirdTemplate.swift
│   │       ├── PackageSwiftGenerator.swift
│   │       └── PackageTemplate.swift
│   └── KolacheCLI/               ← thin ArgumentParser wrapper
│       ├── Kolache.swift
│       └── Commands/
│           └── Init.swift
└── Tests/
    └── KolacheCoreTests/
        └── KolacheCoreTests.swift
```

**KolacheCore** contains all real logic — templates are value types with a
single `generate()` method, `PackageSwiftGenerator` handles all `Package.swift`
variations, and errors flow through `KolacheError`.

**KolacheCLI** is a thin shell — it parses flags, resolves multi-target
detection, and delegates to KolacheCore.

---

## Version Targets

| Component              | Version     |
|------------------------|-------------|
| Swift                  | 6.2         |
| macOS (kolache itself) | 15+         |
| Generated packages     | macOS 15+ / iOS 18+ |
| Generated Xcode apps   | iOS 26 / macOS 26   |
| XcodeGen               | latest via Homebrew  |

---

## Requirements

- Swift 6.2+
- macOS 15+
- Xcode 16+ (for `--app` flag)
