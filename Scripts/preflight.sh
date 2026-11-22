#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

python3 Tools/check-comments.py
xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test
