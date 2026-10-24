#!/bin/zsh
set -euo pipefail
release_fail() { print -u2 "ERRO: $*"; return 1; }

reject_test_artifacts() {
  local app="$1" item
  for item in "$app"/**/*(DN); do
    case "${item:t:l}" in
      *.debug.dylib|__preview.dylib|*xctest*|xct*|xcui*|testing.framework|*.xctestrun|*testmanagerd*|*coresymbolicationd*)
        release_fail "artefato de teste proibido: ${item#$app/}"; return 1 ;;
    esac
  done
}

validate_release_entitlements() {
  local entitlements="$1" key
  print -r -- "$entitlements" | plutil -lint - >/dev/null || { release_fail "entitlements inválidos"; return 1; }
  for key in com.apple.security.get-task-allow get-task-allow; do
    if [[ "$(print -r -- "$entitlements" | plutil -convert json -o - - | jq -r --arg key "$key" '.[$key] // false')" == true ]]; then
      release_fail "entitlement proibido: $key=true"; return 1
    fi
  done
  [[ "${entitlements:l}" != *testmanagerd* ]] || { release_fail "entitlement de testmanagerd proibido"; return 1; }
  [[ "${entitlements:l}" != *coresymbolicationd* ]] || { release_fail "entitlement de coresymbolicationd proibido"; return 1; }
  [[ "$entitlements" != *com.apple.security.app-sandbox* ]] || { release_fail "App Sandbox não pode estar ativo"; return 1; }
  # Hardened Runtime requires Audio Input even when TCC already records consent.
  # Exact equality rejects missing/false/non-Boolean values and every extra privilege.
  [[ "$(print -r -- "$entitlements" | plutil -convert json -o - - | jq '. == {"com.apple.security.device.audio-input": true}')" == true ]] || {
    release_fail "entitlements devem conter somente com.apple.security.device.audio-input=true"; return 1
  }
}

validate_release_app() {
  local app="$1" expected_sha="${2:-}" info signature entitlements recorded_sha
  [[ -d "$app" && ! -L "$app" ]] || { release_fail "bundle ausente ou symlink: $app"; return 1; }
  reject_test_artifacts "$app" || return 1
  info="$app/Contents/Info.plist"
  [[ "$(plutil -extract CFBundleIdentifier raw -o - "$info")" == br.com.luisroquette.Resenha ]] || { release_fail "bundle ID divergente"; return 1; }
  [[ "$(plutil -extract CFBundleExecutable raw -o - "$info")" == Resenha ]] || { release_fail "executável divergente"; return 1; }
  [[ "$(plutil -extract LSMinimumSystemVersion raw -o - "$info")" == 14.0 ]] || { release_fail "deployment target divergente"; return 1; }
  [[ "$(lipo -archs "$app/Contents/MacOS/Resenha")" == arm64 ]] || { release_fail "arquitetura deve ser arm64"; return 1; }
  codesign --verify --deep --strict --verbose=2 "$app" || return 1
  signature="$(codesign -dvv "$app" 2>&1)" || return 1
  [[ "$signature" == *"Authority=Developer ID Application:"* && "$signature" == *"TeamIdentifier=S3YCFYY8SC"* ]] || { release_fail "assinatura Developer ID/team divergente"; return 1; }
  [[ "$signature" == *"flags="*"runtime"* ]] || { release_fail "Hardened Runtime ausente"; return 1; }
  entitlements="$(codesign -d --entitlements :- "$app" 2>/dev/null)" || return 1
  validate_release_entitlements "$entitlements" || return 1
  [[ "$(plutil -extract Configuration raw -o - "$app/Contents/Resources/ResenhaBuild.plist")" == Release ]] || { release_fail "proveniência Release ausente"; return 1; }
  recorded_sha="$(plutil -extract SourceSHA raw -o - "$app/Contents/Resources/ResenhaBuild.plist")" || return 1
  [[ "$recorded_sha" =~ '^[[:xdigit:]]{40}$' ]] || { release_fail "SHA de origem inválido"; return 1; }
  [[ "$(plutil -extract SourceDiffSHA256 raw -o - "$app/Contents/Resources/ResenhaBuild.plist")" =~ '^[[:xdigit:]]{64}$' ]] || { release_fail "hash das fontes ausente"; return 1; }
  if [[ -n "$expected_sha" ]]; then
    [[ "$recorded_sha" == "$expected_sha" ]] || { release_fail "SHA de origem divergente"; return 1; }
  fi
}

release_manifest() {
  (cd "$1" && find . -type f -exec shasum -a 256 {} + | LC_ALL=C sort)
}

release_fingerprint() { release_manifest "$1" | shasum -a 256 | awk '{print $1}'; }

if [[ "$ZSH_EVAL_CONTEXT" != toplevel ]]; then return 0; fi
if [[ "${1:-}" == --app ]]; then
  shift
  validate_release_app "$@"
  print "Bundle Release válido: $1"
  exit 0
fi

dmg="${1:-}"
mode="${2:-after-notarization}"
[[ -f "$dmg" ]] || { print -u2 "ERRO: informe um DMG existente"; exit 1; }

hdiutil verify "$dmg" >/dev/null
codesign --verify --verbose=2 "$dmg"

mount_info="$(hdiutil attach -readonly -nobrowse -plist "$dmg")"
mount_point="$(print -r -- "$mount_info" | plutil -extract system-entities xml1 -o - - | plutil -convert json -o - - | jq -r '.[] | select(."mount-point" != null) | ."mount-point"' | tail -1)"
[[ -n "$mount_point" ]] || { print -u2 "ERRO: volume não montado"; exit 1; }
detach_release_volume() {
  local result=$?
  if ! hdiutil detach "$mount_point" >/dev/null; then
    print -u2 "ERRO: não foi possível desmontar $mount_point"
    (( result != 0 )) || result=1
  fi
  return "$result"
}
trap detach_release_volume EXIT
[[ -d "$mount_point/Resenha.app" ]] || { print -u2 "ERRO: app ausente no DMG"; exit 1; }

app="$mount_point/Resenha.app"
info="$app/Contents/Info.plist"
validate_release_app "$app"
[[ -L "$mount_point/Applications" && "$(readlink "$mount_point/Applications")" == "/Applications" ]]

if [[ "$mode" != "--before-notarization" ]]; then
  xcrun stapler validate "$dmg"
  spctl -a -vv -t open --context context:primary-signature "$dmg"
fi
print "DMG válido: Resenha $(plutil -extract CFBundleShortVersionString raw "$info") ($(plutil -extract CFBundleVersion raw "$info")), arm64, sem sandbox"
