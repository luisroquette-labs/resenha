#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
source "$project_root/Scripts/release-source-contract.sh"
release_state="$project_root/AppStore/release-state.json"
source_commit="${1:-$(git -C "$project_root" rev-parse HEAD)}"

validate_release_source_commit "$project_root" "$source_commit"
plutil -replace candidate.sourceCommit -string "$source_commit" "$release_state"
print "PASS: candidato vinculado ao source commit $source_commit"
