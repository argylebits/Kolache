# Kolache Code Review — 2026-03-02

Updated: 2026-03-09

## Resolved

- ~~**#1** Orphaned `Sources/Kolache.swift`~~ — Deleted.
- ~~**#2** `CoreTemplate` and `PackageTemplate` identical~~ — `CoreTemplate` deleted, `PackageTemplate` used for both.
- ~~**#3** `--package` flag in multi-target~~ — `--package` now explicitly creates `<Name>Core/`. Without it, no Core is generated.
- ~~**#4** Dead `app` field on `PackageSwiftGenerator`~~ — Removed.
- ~~**#5** Dead code path in `Init.swift`~~ — Removed.
- ~~**#7** No cleanup on failure / `--force` flag~~ — `--force` flag added. Deletes existing directory before recreating.
- ~~**#8** `KolacheConfig` untestable~~ — `KolacheConfig` removed entirely. No interactive prompts. Bundle ID and org name are handled by Xcode, not Kolache.
- ~~`Tests/KolacheTests/` empty placeholder~~ — Deleted.
- ~~`Config.swift` command~~ — Deleted along with `KolacheConfig`.
- ~~`--git` creating initial commit~~ — Simplified to just `git init`. No staging or committing.
- ~~Git context detection / `isInsideRepo`~~ — Removed. Git output is passed through as-is.
- ~~File header comments (`Created by`)~~ — Removed from all templates.
- ~~`bundleIdPrefix` / bundle ID in project.yml~~ — Removed. Users configure signing in Xcode.

## Open

### 6. No project name validation

Names with spaces, hyphens, special characters, or Swift reserved words produce broken `Package.swift` files and invalid struct names. Add a regex check on `projectName`. Tracked as GitHub issue #3 (contribute to swift-package-manager).

## Testing Gaps

- ~~**Temp directory cleanup**~~ — Consolidated under single `kolache-tests/` root, wiped at start of each run.
- **No negative tests**: Empty project names, names with `/`, duplicate flags — blocked on #3 (name validation).

## Minor

- `XcodeGenRunner` auto-installing Homebrew via `curl | bash` is aggressive. Worth an explicit confirmation or a "install it yourself" fallback.
- Generated `Package.swift` template code is hard to read due to nested string interpolation. Functional but difficult to modify.
