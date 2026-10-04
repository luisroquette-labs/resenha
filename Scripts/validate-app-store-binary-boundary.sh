#!/bin/zsh
set -euo pipefail

binary="${1:?uso: Scripts/validate-app-store-binary-boundary.sh <executável Resenha>}"
[[ -f "$binary" ]] || { print -u2 "FALHOU: executável ausente: $binary"; exit 1; }

symbols="$(/usr/bin/nm -u "$binary" | awk '{print $NF}')"
for forbidden in \
  _AXIsProcessTrusted \
  _AXIsProcessTrustedWithOptions \
  _AXUIElementCreateApplication \
  _CGEventPost; do
  if print -r -- "$symbols" | grep -Fqx "$forbidden"; then
    print -u2 "FALHOU: API proibida no binário App Store: $forbidden"
    exit 1
  fi
done

print "PASS: binário App Store sem Accessibility ou postagem sintética"
