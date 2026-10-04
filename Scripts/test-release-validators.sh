#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
archive="${1:?uso: Scripts/test-release-validators.sh <archive.xcarchive>}"
validator="$project_root/Scripts/validate-app-store-package.sh"
binary_boundary_validator="$project_root/Scripts/validate-app-store-binary-boundary.sh"
state="$project_root/AppStore/release-state.json"
work_root="$(mktemp -d "${TMPDIR:-/tmp}/resenha-validator-test.XXXXXX")"
trap 'mv "$work_root" "$HOME/.Trash/resenha-validator-test-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true' EXIT

negative_only="${RESENHA_NEGATIVE_ONLY:-0}"
if [[ "$negative_only" != 1 ]]; then
  "$validator" "$archive" "$state"
fi
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
ditto "$archive" "$work_root/build-mismatch.xcarchive"
plutil -replace CFBundleVersion -string 3 \
  "$work_root/build-mismatch.xcarchive/Products/Applications/Resenha.app/Contents/Info.plist"
if "$validator" "$work_root/build-mismatch.xcarchive" "$state" >"$work_root/build-mismatch.log" 2>&1; then
  print -u2 "FALHOU: validador aceitou build divergente"
  exit 1
fi
grep -q 'build do archive (3) diverge da fonte (2)' "$work_root/build-mismatch.log" || {
  print -u2 "FALHOU: mismatch não falhou pelo contrato de build"
  exit 1
}
if [[ "$negative_only" == 1 ]]; then
  function assert_ax_symbol_rejected() {
    local symbol="$1"
    local source="$work_root/forbidden-$symbol.c"
    local binary="$work_root/forbidden-$symbol"
    local log="$work_root/forbidden-$symbol.log"
    print "extern int $symbol(void *, void *, void **);" > "$source"
    print "int main(void) { return $symbol(0, 0, 0); }" >> "$source"
    xcrun clang "$source" -framework ApplicationServices -o "$binary"
    if "$binary_boundary_validator" "$binary" >"$log" 2>&1; then
      print -u2 "FALHOU: validador aceitou símbolo $symbol"
      exit 1
    fi
    grep -q "API proibida no binário App Store: _$symbol" "$log" || {
      print -u2 "FALHOU: $symbol não acionou o diagnóstico de símbolo esperado"
      exit 1
    }
  }

  assert_ax_symbol_rejected AXUIElementCopyAttributeValue
  assert_ax_symbol_rejected AXObserverCreate

  clean_source="$work_root/clean.c"
  clean_binary="$work_root/clean"
  print 'int main(void) { return 0; }' > "$clean_source"
  xcrun clang "$clean_source" -o "$clean_binary"
  "$binary_boundary_validator" "$clean_binary" >"$work_root/clean.log"
  grep -q 'PASS: binário App Store sem Accessibility ou postagem sintética' "$work_root/clean.log" || {
    print -u2 "FALHOU: fixture limpa não produziu o aceite esperado"
    exit 1
  }
  print "PASS: versão, source commit e build divergentes rejeitados; dois AX rejeitados; fixture limpa aceita"
else
  print "PASS: pacote exato aceito; versão, source commit e build divergentes rejeitados"
fi
