#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
source "$project_root/Scripts/release-source-contract.sh"
release_state="$project_root/AppStore/release-state.json"
source_commit="$(plutil -extract candidate.sourceCommit raw "$release_state" 2>/dev/null || true)"
version="$(awk '/MARKETING_VERSION:/{print $2; exit}' "$project_root/project.yml")"
build="$(awk '/CURRENT_PROJECT_VERSION:/{print $2; exit}' "$project_root/project.yml")"
archive="${1:-$project_root/build/archive/Resenha-${version}-b${build}.xcarchive}"

validate_release_source_commit "$project_root" "$source_commit"
mkdir -p "${archive:h}"
"$HOME/.local/bin/mac-gate" xcodebuild \
  -project "$project_root/WhisperKey.xcodeproj" \
  -scheme ResenhaAppStore \
  -configuration AppStore \
  -destination 'generic/platform=macOS' \
  -archivePath "$archive" \
  RESENHA_SOURCE_COMMIT="$source_commit" \
  archive
print "PASS: archive $archive vinculado ao source commit $source_commit"
