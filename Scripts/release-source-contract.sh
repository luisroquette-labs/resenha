#!/bin/zsh

# Shared provenance contract for release preparation, archive creation and validation.
release_relevant_paths=(
  Config
  Sources
  Resources
  Frameworks
  Vendor/whisper.cpp
  Scripts
  project.yml
  WhisperKey.xcodeproj
  THIRD_PARTY_NOTICES.md
)

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
  [[ "$source_commit" == "$head_commit" ]] \
    || { release_source_fail "source commit $source_commit diverge do HEAD $head_commit"; return 1; }
  git -C "$project_root" diff --quiet "$source_commit" -- $release_relevant_paths \
    || { release_source_fail "fontes relevantes divergem do source commit"; return 1; }
  git -C "$project_root" diff --cached --quiet "$source_commit" -- $release_relevant_paths \
    || { release_source_fail "fontes relevantes staged divergem do source commit"; return 1; }
  untracked="$(git -C "$project_root" ls-files --others --exclude-standard -- $release_relevant_paths)"
  [[ -z "$untracked" ]] \
    || { release_source_fail "fontes relevantes sem commit: ${(f)untracked}"; return 1; }
}
