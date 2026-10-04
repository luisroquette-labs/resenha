#!/bin/zsh
set -euo pipefail

dmg="${1:-}"
mode="${2:-after-notarization}"
[[ -f "$dmg" ]] || { print -u2 "ERRO: informe um DMG existente"; exit 1; }

hdiutil verify "$dmg" >/dev/null
codesign --verify --verbose=2 "$dmg"

mount_info="$(hdiutil attach -readonly -nobrowse -plist "$dmg")"
mount_point="$(print -r -- "$mount_info" | plutil -extract system-entities xml1 -o - - | plutil -convert json -o - - | jq -r '.[] | select(."mount-point" != null) | ."mount-point"' | tail -1)"
[[ -n "$mount_point" ]] || { print -u2 "ERRO: volume não montado"; exit 1; }
trap 'hdiutil detach "$mount_point" >/dev/null 2>&1 || true' EXIT
[[ -d "$mount_point/Resenha.app" ]] || { print -u2 "ERRO: app ausente no DMG"; exit 1; }

app="$mount_point/Resenha.app"
info="$app/Contents/Info.plist"
[[ "$(plutil -extract CFBundleIdentifier raw "$info")" == "br.com.luisroquette.Resenha" ]]
[[ "$(plutil -extract LSMinimumSystemVersion raw "$info")" == "14.0" ]]
[[ "$(lipo -archs "$app/Contents/MacOS/Resenha")" == "arm64" ]]
codesign --verify --deep --strict --verbose=2 "$app"
signature="$(codesign -dvv "$app" 2>&1)"
[[ "$signature" == *"Authority=Developer ID Application:"* ]] || { print -u2 "ERRO: assinatura não usa Developer ID"; exit 1; }
[[ "$signature" == *"flags="*"runtime"* ]] || { print -u2 "ERRO: Hardened Runtime ausente"; exit 1; }
entitlements="$(codesign -d --entitlements :- "$app" 2>/dev/null || true)"
[[ "$entitlements" != *"com.apple.security.app-sandbox"* ]] || { print -u2 "ERRO: App Sandbox não pode estar ativo"; exit 1; }
[[ -L "$mount_point/Applications" && "$(readlink "$mount_point/Applications")" == "/Applications" ]]

if [[ "$mode" != "--before-notarization" ]]; then
  xcrun stapler validate "$dmg"
  spctl -a -vv -t open --context context:primary-signature "$dmg"
fi
print "DMG válido: Resenha $(plutil -extract CFBundleShortVersionString raw "$info") ($(plutil -extract CFBundleVersion raw "$info")), arm64, sem sandbox"
