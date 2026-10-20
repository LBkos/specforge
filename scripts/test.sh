#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "xcodegen is required. Install it with: brew install xcodegen" >&2
    exit 1
fi

xcodegen generate >/dev/null
xcodebuild \
    -project SpecForge.xcodeproj \
    -scheme SpecForge \
    -configuration Debug \
    -derivedDataPath build \
    -destination 'platform=macOS' \
    test
