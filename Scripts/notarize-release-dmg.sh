#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
dmg="${1:-$project_root/build/direct/Resenha-1.0.0-arm64.dmg}"
profile="${RESENHA_NOTARY_PROFILE:-notchagent-notary}"

[[ -f "$dmg" ]] || { print -u2 "ERRO: DMG ausente: $dmg"; exit 1; }
xcrun notarytool submit "$dmg" --keychain-profile "$profile" --wait
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
"$project_root/Scripts/validate-release-dmg.sh" "$dmg"
shasum -a 256 "$dmg" > "$dmg.sha256"
print "DMG notarizado: $dmg"
