#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
source "$project_root/Scripts/release-source-contract.sh"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/resenha-source-contract.XXXXXX")"
trap 'mv "$fixture" "$HOME/.Trash/resenha-source-contract-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true' EXIT

git -C "$fixture" init -q
git -C "$fixture" config user.name "Resenha Contract Test"
git -C "$fixture" config user.email "release-contract@invalid.example"
mkdir -p "$fixture/Sources"
print 'release source' > "$fixture/Sources/App.swift"
git -C "$fixture" add Sources/App.swift
git -C "$fixture" commit -q -m fixture
commit="$(git -C "$fixture" rev-parse HEAD)"

validate_release_source_commit "$fixture" "$commit"
print 'dirty' >> "$fixture/Sources/App.swift"
if validate_release_source_commit "$fixture" "$commit" >/dev/null 2>&1; then
  print -u2 "FALHOU: contrato aceitou fonte relevante suja"
  exit 1
fi
git -C "$fixture" restore Sources/App.swift
if validate_release_source_commit "$fixture" 0000000000000000000000000000000000000000 >/dev/null 2>&1; then
  print -u2 "FALHOU: contrato aceitou commit inexistente"
  exit 1
fi
print "PASS: source commit real aceito; árvore suja e commit inexistente rejeitados"
