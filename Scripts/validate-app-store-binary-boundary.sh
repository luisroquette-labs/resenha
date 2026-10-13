#!/bin/zsh
set -euo pipefail

binary="${1:?uso: Scripts/validate-app-store-binary-boundary.sh <executável Resenha>}"
[[ -f "$binary" ]] || { print -u2 "FALHOU: executável ausente: $binary"; exit 1; }

symbols="$(/usr/bin/nm "$binary")" || {
  print -u2 "FALHOU: não foi possível inspecionar símbolos do binário App Store"
  exit 1
}
forbidden_symbol="$(print -r -- "$symbols" | awk '
  {
    for (i = 1; i <= NF; i++) {
      if ($i ~ /^_AX/ || $i ~ /^_CGEventPost/ || $i ~ /^_CG(EventTapCreate|PreflightListenEventAccess|RequestListenEventAccess)/) {
        print $i
        exit
      }
    }
  }
')"
if [[ -n "$forbidden_symbol" ]]; then
  print -u2 "FALHOU: API proibida no binário App Store: $forbidden_symbol"
  exit 1
fi
if ! print -r -- "$symbols" | awk '$NF == "_RegisterEventHotKey" { found = 1 } END { exit !found }'; then
  print -u2 "FALHOU: atalho registrado ausente do binário App Store"
  exit 1
fi

linked_frameworks="$(otool -L "$binary")"
forbidden_framework="$(print -r -- "$linked_frameworks" | awk '
  /\/ApplicationServices\.framework\// || /\/HIServices\.framework\// || /\/Accessibility\.framework\// {
    print $1
    exit
  }
')"
if [[ -n "$forbidden_framework" ]]; then
  print -u2 "FALHOU: framework de Accessibility proibido no binário App Store: $forbidden_framework"
  exit 1
fi

forbidden_string="$(strings -a "$binary" | awk '
  /^_?AX[A-Z][A-Za-z0-9_]*$/ || /^_?CGEventPost[A-Za-z0-9_]*$/ || /^_?CG(EventTapCreate|PreflightListenEventAccess|RequestListenEventAccess)$/ {
    print
    exit
  }
')"
if [[ -n "$forbidden_string" ]]; then
  print -u2 "FALHOU: referência textual a API proibida no binário App Store: $forbidden_string"
  exit 1
fi

print "PASS: binário App Store com atalho registrado, sem monitoramento de entrada, Accessibility ou postagem sintética"
