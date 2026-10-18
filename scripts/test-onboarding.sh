#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_BUILD="$(mktemp -d "${TMPDIR:-/tmp/}roost-onboarding-tests.XXXXXX")"
trap 'rm -rf "$TEST_BUILD"' EXIT
mkdir -p "$TEST_BUILD/Sources"
SOURCES=()
for source in "$ROOT"/app/Roost/*.swift; do
    if [[ "$source" != */RoostApp.swift ]]; then
        cp "$source" "$TEST_BUILD/Sources/"
        SOURCES+=("$TEST_BUILD/Sources/$(basename "$source")")
    fi
done
cp "$ROOT/tests/OnboardingTests.swift" "$TEST_BUILD/OnboardingTests.swift"
TEST_ARCH="$(uname -m)"
swiftc -swift-version 5 -target "$TEST_ARCH-apple-macos13.0" \
    -framework SwiftUI -framework AppKit -framework WebKit -framework ScreenCaptureKit \
    "${SOURCES[@]}" "$TEST_BUILD/OnboardingTests.swift" -o "$TEST_BUILD/RoostOnboardingTests"
"$TEST_BUILD/RoostOnboardingTests"
