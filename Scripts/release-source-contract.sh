#!/bin/zsh

# Shared provenance contract for release preparation, archive creation and validation.
release_relevant_paths=(
  Config
  Sources
  Resources
  Frameworks
  Vendor/whisper.cpp
  Scripts/archive-release-candidate.sh
  Scripts/build-whisper-framework.sh
  Scripts/export-app-store-screenshots.sh
  AppStore
  ':(exclude)AppStore/release-state.json'
  project.yml
  WhisperKey.xcodeproj
  THIRD_PARTY_NOTICES.md
)

# Deliberately excluded from archive provenance: `.specs/**`, `docs/**`, README files,
# the independently tested marketing site, validators and `AppStore/release-state.json`.
# They may change in descendant commits but cannot alter the archived executable,
# its build inputs or the App Store submission assets.

release_source_fail() {
  print -u2 "FALHOU: $*"
  return 1
}

validate_release_source_commit() {
  local project_root="$1"
  local source_commit="$2"
  local head_commit
  local untracked

  [[ "$source_commit" =~ ^[0-9a-f]{40}$ ]] \
    || { release_source_fail "source commit precisa ser um SHA-1 completo"; return 1; }
  git -C "$project_root" cat-file -e "$source_commit^{commit}" 2>/dev/null \
    || { release_source_fail "source commit não existe no repositório: $source_commit"; return 1; }
  head_commit="$(git -C "$project_root" rev-parse HEAD)"
  git -C "$project_root" merge-base --is-ancestor "$source_commit" "$head_commit" \
    || { release_source_fail "source commit não é ancestral do HEAD $head_commit"; return 1; }
  git -C "$project_root" diff --quiet "$source_commit..$head_commit" -- $release_relevant_paths \
    || { release_source_fail "descendentes alteraram fontes relevantes desde o source commit"; return 1; }
  git -C "$project_root" diff --quiet "$head_commit" -- $release_relevant_paths \
    || { release_source_fail "worktree alterou fontes relevantes desde o HEAD"; return 1; }
  git -C "$project_root" diff --cached --quiet "$head_commit" -- $release_relevant_paths \
    || { release_source_fail "fontes relevantes staged divergem do source commit"; return 1; }
  untracked="$(git -C "$project_root" ls-files --others --exclude-standard -- $release_relevant_paths)"
  [[ -z "$untracked" ]] \
    || { release_source_fail "fontes relevantes sem commit: ${(f)untracked}"; return 1; }
}
