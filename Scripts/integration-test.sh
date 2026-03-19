#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
KOLACHE="$REPO_ROOT/.build/release/kolache"
TEMP_ROOT="$(mktemp -d)"
PASSED=0
FAILED=0
FAILURES=()

cleanup() {
    rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT

# Build kolache if needed
if [[ ! -x "$KOLACHE" ]]; then
    echo "Building kolache..."
    swift build -c release --package-path "$REPO_ROOT" 2>&1 | tail -1
fi

echo "Using: $KOLACHE"
echo "Temp dir: $TEMP_ROOT"
echo ""

pass_test() {
    local name="$1"
    echo "  PASS"
    PASSED=$((PASSED + 1))
    echo ""
}

fail_test() {
    local name="$1"
    local reason="$2"
    echo "  FAIL: $reason"
    FAILED=$((FAILED + 1))
    FAILURES+=("$name")
    echo ""
}

run_test() {
    local name="$1"
    shift
    local flags=("$@")
    local project_dir="$TEMP_ROOT/$name"

    echo "--- $name: kolache init ${flags[*]} ---"

    if ! "$KOLACHE" init "$name" "${flags[@]}" --force 2>&1 | sed 's/^/  /'; then
        fail_test "$name" "kolache init failed"
        return
    fi

    # Find the directory to build — single-target is at root, multi-target has sub-packages
    local build_targets=()
    for dir in "$project_dir"/*/; do
        if [[ -f "$dir/Package.swift" ]]; then
            build_targets+=("$dir")
        fi
    done

    # If no sub-package Package.swift found, try root
    if [[ ${#build_targets[@]} -eq 0 ]] && [[ -f "$project_dir/Package.swift" ]]; then
        build_targets=("$project_dir")
    fi

    if [[ ${#build_targets[@]} -eq 0 ]]; then
        echo "  SKIP: no Package.swift found (--app only generates xcodeproj)"
        PASSED=$((PASSED + 1))
        echo ""
        return
    fi

    local all_built=true
    for target in "${build_targets[@]}"; do
        local target_name
        target_name="$(basename "$target")"
        echo "  Building $target_name..."
        if ! swift build --package-path "$target" 2>&1 | sed 's/^/    /'; then
            echo "  FAIL: swift build failed for $target_name"
            all_built=false
        fi
    done

    if $all_built; then
        pass_test "$name"
    else
        fail_test "$name" "swift build failed"
    fi
}

test_version() {
    echo "--- kolache --version ---"
    local output
    output="$("$KOLACHE" --version 2>&1)"
    echo "  $output"
    if [[ "$output" == Kolache\ v* ]]; then
        pass_test "version"
    else
        fail_test "version" "expected 'Kolache v...' but got '$output'"
    fi
}

test_git() {
    local name="TestGit"
    local project_dir="$TEMP_ROOT/$name"

    echo "--- $name: kolache init --cli --git ---"

    if ! "$KOLACHE" init "$name" --cli --git --force 2>&1 | sed 's/^/  /'; then
        fail_test "$name" "kolache init failed"
        return
    fi

    if [[ ! -d "$project_dir/.git" ]]; then
        fail_test "$name" ".git directory not found"
        return
    fi

    if [[ ! -f "$project_dir/.gitignore" ]]; then
        fail_test "$name" ".gitignore not found"
        return
    fi

    pass_test "$name"
}

test_force() {
    local name="TestForce"
    local project_dir="$TEMP_ROOT/$name"

    echo "--- $name: kolache init --force overwrites existing ---"

    # Create the project once
    if ! "$KOLACHE" init "$name" --cli --force 2>&1 | sed 's/^/  /'; then
        fail_test "$name" "first kolache init failed"
        return
    fi

    # Drop a marker file
    touch "$project_dir/marker.txt"

    # Re-create with --force
    if ! "$KOLACHE" init "$name" --package --force 2>&1 | sed 's/^/  /'; then
        fail_test "$name" "second kolache init --force failed"
        return
    fi

    if [[ -f "$project_dir/marker.txt" ]]; then
        fail_test "$name" "marker.txt still exists — --force did not wipe directory"
        return
    fi

    pass_test "$name"
}

test_recipe_version_plugin() {
    local name="TestRecipe"
    local project_dir="$TEMP_ROOT/$name"

    echo "--- $name: kolache recipe version-plugin on generated project ---"

    # Generate a CLI project
    if ! "$KOLACHE" init "$name" --cli --force 2>&1 | sed 's/^/  /'; then
        fail_test "$name" "kolache init failed"
        return
    fi

    # Apply the recipe (uses current directory)
    if ! (cd "$project_dir" && "$KOLACHE" recipe version-plugin) 2>&1 | sed 's/^/  /'; then
        fail_test "$name" "kolache recipe version-plugin failed"
        return
    fi

    # Verify it still builds
    echo "  Building after recipe..."
    if ! swift build --package-path "$project_dir" 2>&1 | sed 's/^/    /'; then
        fail_test "$name" "swift build failed after applying recipe"
        return
    fi

    pass_test "$name"
}

# Change to temp dir so kolache creates projects there
cd "$TEMP_ROOT"

# Basics
test_version

# Single-flag tests
run_test "TestCLI" --cli
run_test "TestPackage" --package
run_test "TestHummingbird" --hummingbird
run_test "TestApp" --app

# Multi-flag tests
run_test "TestMultiCHP" --cli --hummingbird --package
run_test "TestMultiACP" --app --cli --package
run_test "TestMultiCH" --cli --hummingbird

# Feature tests
test_git
test_force
test_recipe_version_plugin

echo "==================================="
echo "Results: $PASSED passed, $FAILED failed"
if [[ $FAILED -gt 0 ]]; then
    echo "Failures: ${FAILURES[*]}"
    exit 1
fi
