# Kolache Code Review — 2026-03-02

## Issues to Address

### 1. Orphaned file: `Sources/Kolache.swift`

Untracked leftover from early development. Contains a standalone `@main` struct that would conflict with the real entry point in `Sources/KolacheCLI/Kolache.swift`. Delete it.

### 2. `CoreTemplate` and `PackageTemplate` are identical

Both generate the exact same output — a public struct with `public init() {}` and a Swift Testing test file. Eliminate one and reuse the other.

### 3. `--package` flag silently swallowed in multi-target

`generateMultiTarget()` in `Init.swift` handles `app`, `cli`, and `hummingbird` but has no branch for `package`. Running `kolache init Foo --package --cli` creates `FooCore` and `FooCLI` but the `--package` flag produces nothing. Arguably correct (Core *is* the library), but should at minimum print a note, or be documented.

### 4. `app` field on `PackageSwiftGenerator` is dead code

The instance property `app: Bool` is accepted by the initializer but never read. App targets go through XcodeGen directly. The field only matters in the static `isMultiTarget()` method, which takes its own parameters.

### 5. Dead code path in `Init.swift:59-61`

```swift
if isMultiTarget && !hasAnyFlag {
    // Multi-target requires at least one generation flag
}
```

This condition is impossible — `isMultiTarget` requires 2+ flags, which guarantees `hasAnyFlag` is true. The empty body makes it doubly inert.

### 6. No project name validation

Names with spaces, hyphens, special characters, or Swift reserved words produce broken `Package.swift` files, invalid struct names, and bad bundle IDs. Add a regex check on `projectName`.

### 7. No cleanup on failure

If generation fails partway (xcodegen crash, disk full, etc.), the partially-created project directory is left behind. The next run then fails with "directory already exists." Consider a rollback mechanism or a `--force` flag.

### 8. `KolacheConfig` is untestable

`loadOrCreate()` calls `readLine()` directly. No way to inject input in tests, so the config path has zero test coverage. Extract an `input: () -> String?` parameter or a protocol.

## Testing Gaps

- **Temp directory cleanup**: Every test creates `kolache-tests-UUID` directories in `/tmp` and never removes them.
- **`Tests/KolacheTests/KolacheTests.swift`** is an empty placeholder. Remove or fill it.
- **Config and Init commands have no direct tests** due to stdin/filesystem coupling.
- **No negative tests**: Empty project names, names with `/`, duplicate flags — all unvalidated and untested.

## Minor

- `.DS_Store` appears twice in `GitIgnore.swift` (lines 7 and 55).
- `XcodeGenRunner` auto-installing Homebrew via `curl | bash` is aggressive. Worth an explicit confirmation or a "install it yourself" fallback.
- Generated `Package.swift` template code is hard to read due to nested string interpolation. Functional but difficult to modify.
