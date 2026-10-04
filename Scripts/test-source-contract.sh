#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
source "$project_root/Scripts/release-source-contract.sh"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/resenha-source-contract.XXXXXX")"
trap 'mv "$fixture" "$HOME/.Trash/resenha-source-contract-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true' EXIT

git -C "$fixture" init -q
git -C "$fixture" config user.name "Resenha Contract Test"
git -C "$fixture" config user.email "release-contract@invalid.example"
mkdir -p "$fixture/Sources" "$fixture/Scripts" "$fixture/Config" \
  "$fixture/site/assets/product" "$fixture/AppStore/screenshots" "$fixture/docs" "$fixture/.specs"
print 'release source' > "$fixture/Sources/App.swift"
print 'release script' > "$fixture/Scripts/release.sh"
print 'release config' > "$fixture/Config/App.plist"
print 'site media' > "$fixture/site/assets/product/demo.mp4"
print 'store media' > "$fixture/AppStore/screenshots/store.png"
print '{"candidate":null}' > "$fixture/AppStore/release-state.json"
git -C "$fixture" add .
git -C "$fixture" commit -q -m fixture
commit="$(git -C "$fixture" rev-parse HEAD)"

validate_release_source_commit "$fixture" "$commit"

print 'evidence' > "$fixture/docs/release-evidence.md"
print 'task state' > "$fixture/.specs/release-task.md"
print 'unrelated user documentation' > "$fixture/README.md"
print '{"candidate":"recorded"}' > "$fixture/AppStore/release-state.json"
git -C "$fixture" add .
git -C "$fixture" commit -q -m 'metadata-only descendant'
validate_release_source_commit "$fixture" "$commit"

function assert_relevant_change_rejected() {
  local relative_file="$1"
  local original_content="$2"
  local changed_content="$3"
  local label="$4"
  print -r -- "$changed_content" > "$fixture/$relative_file"
  git -C "$fixture" add "$relative_file"
  git -C "$fixture" commit -q -m "change $label"
  if validate_release_source_commit "$fixture" "$commit" >/dev/null 2>&1; then
    print -u2 "FALHOU: contrato aceitou mudança relevante em $label"
    exit 1
  fi
  print -r -- "$original_content" > "$fixture/$relative_file"
  git -C "$fixture" add "$relative_file"
  git -C "$fixture" commit -q -m "restore $label"
  validate_release_source_commit "$fixture" "$commit"
}

assert_relevant_change_rejected Sources/App.swift 'release source' 'changed app source' 'app source'
assert_relevant_change_rejected Scripts/release.sh 'release script' 'changed release script' 'release script'
assert_relevant_change_rejected Config/App.plist 'release config' 'changed release config' 'release config'
assert_relevant_change_rejected site/assets/product/demo.mp4 'site media' 'changed site media' 'site media'
assert_relevant_change_rejected AppStore/screenshots/store.png 'store media' 'changed store media' 'store media'

print 'dirty' >> "$fixture/Sources/App.swift"
if validate_release_source_commit "$fixture" "$commit" >/dev/null 2>&1; then
  print -u2 "FALHOU: contrato aceitou fonte relevante suja"
  exit 1
fi
git -C "$fixture" restore Sources/App.swift
print 'untracked' > "$fixture/Scripts/untracked.sh"
if validate_release_source_commit "$fixture" "$commit" >/dev/null 2>&1; then
  print -u2 "FALHOU: contrato aceitou script relevante sem commit"
  exit 1
fi
if validate_release_source_commit "$fixture" 0000000000000000000000000000000000000000 >/dev/null 2>&1; then
  print -u2 "FALHOU: contrato aceitou commit inexistente"
  exit 1
fi
print "PASS: descendente só de metadados/docs aceito; fonte, script, config, mídia, worktree e commit inválido rejeitados"
