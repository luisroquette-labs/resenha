#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
archive="${1:?uso: Scripts/test-release-validators.sh <archive.xcarchive>}"
validator="$project_root/Scripts/validate-app-store-package.sh"
state="$project_root/AppStore/release-state.json"
work_root="$(mktemp -d "${TMPDIR:-/tmp}/resenha-validator-test.XXXXXX")"
trap 'mv "$work_root" "$HOME/.Trash/resenha-validator-test-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true' EXIT

"$validator" "$archive" "$state"
cp "$state" "$work_root/mismatch.json"
plutil -replace candidate.version -string 99.99.99 "$work_root/mismatch.json"
if "$validator" "$archive" "$work_root/mismatch.json" >"$work_root/mismatch.log" 2>&1; then
  print -u2 "FALHOU: validador aceitou versão divergente"
  exit 1
fi
grep -q 'diverge do candidato' "$work_root/mismatch.log" || {
  print -u2 "FALHOU: mismatch não falhou pelo contrato de versão"
  exit 1
}
cp "$state" "$work_root/commit-mismatch.json"
plutil -replace candidate.sourceCommit -string 0000000000000000000000000000000000000000 "$work_root/commit-mismatch.json"
if "$validator" "$archive" "$work_root/commit-mismatch.json" >"$work_root/commit-mismatch.log" 2>&1; then
  print -u2 "FALHOU: validador aceitou source commit divergente"
  exit 1
fi
grep -q 'source commit do archive diverge do candidato' "$work_root/commit-mismatch.log" || {
  print -u2 "FALHOU: mismatch não falhou pelo contrato de source commit"
  exit 1
}
print "PASS: pacote exato aceito; versão e source commit divergentes rejeitados"
