#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
source_version="$(awk '/MARKETING_VERSION:/{print $2; exit}' "$project_root/project.yml")"
source_build="$(awk '/CURRENT_PROJECT_VERSION:/{print $2; exit}' "$project_root/project.yml")"
archive="${1:-$project_root/build/archive/Resenha-${source_version}-b${source_build}.xcarchive}"
release_state="${2:-$project_root/AppStore/release-state.json}"
screenshots="$project_root/AppStore/screenshots/pt-BR"
metadata="$project_root/AppStore/metadata/pt-BR.md"
info_source="$project_root/Config/ResenhaStore-Info.plist"
source "$project_root/Scripts/release-source-contract.sh"

fail() { print -u2 "FALHOU: $*"; exit 1; }
pass() { print "PASS: $*"; }
entitlements="$(mktemp "${TMPDIR:-/tmp}/resenha-entitlements.XXXXXX")"
trap 'rm -f "$entitlements"' EXIT

[[ -f "$metadata" ]] || fail "metadados ausentes"
store_name="$(sed -n '1s/^# //p' "$metadata")"
subtitle="$(awk '/^## Subtítulo$/{getline; getline; print; exit}' "$metadata")"
promotional="$(awk '/^## Texto promocional$/{getline; getline; print; exit}' "$metadata")"
keywords="$(awk '/^## Palavras-chave$/{getline; getline; print; exit}' "$metadata")"
(( ${#store_name} <= 30 )) || fail "nome excede 30 caracteres"
(( ${#subtitle} <= 30 )) || fail "subtítulo excede 30 caracteres"
(( ${#promotional} <= 170 )) || fail "texto promocional excede 170 caracteres"
(( ${#keywords} <= 100 )) || fail "palavras-chave excedem 100 caracteres"
[[ "$keywords" != *" "* ]] || fail "palavras-chave contêm espaços desperdiçados"
pass "limites de metadados da loja"

[[ "$(find "$screenshots" -maxdepth 1 -name '*.png' | wc -l | tr -d ' ')" == 10 ]] || fail "esperadas 10 screenshots"
for image in "$screenshots"/*.png; do
  [[ "$(sips -g pixelWidth "$image" 2>/dev/null | awk '/pixelWidth/{print $2}')" == 2880 ]] || fail "largura inválida: ${image:t}"
  [[ "$(sips -g pixelHeight "$image" 2>/dev/null | awk '/pixelHeight/{print $2}')" == 1800 ]] || fail "altura inválida: ${image:t}"
  [[ "$(sips -g hasAlpha "$image" 2>/dev/null | awk '/hasAlpha/{print $2}')" == no ]] || fail "alpha presente: ${image:t}"
done
pass "10 screenshots 2880 × 1800 sem alpha"

[[ "$(plutil -extract ITSAppUsesNonExemptEncryption raw "$info_source")" == false ]] || fail "declaração de criptografia"
[[ "$(plutil -extract CFBundleIdentifier raw "$info_source")" == '$(PRODUCT_BUNDLE_IDENTIFIER)' ]] || fail "bundle identifier parametrizado"
pass "Info.plist e export compliance"

for forbidden in '*.p8' '*.pem' '*.key'; do
  [[ -z "$(find "$project_root/AppStore" -type f -name "$forbidden" -print -quit)" ]] || fail "credencial em AppStore/"
done
rg -q 'AQ\.Ab8RN6' "$project_root" --glob '!build/**' && fail "prefixo de chave exposto"
pass "nenhuma credencial nos ativos"

[[ -d "$archive" ]] || fail "archive ausente: $archive"
[[ -f "$release_state" ]] || fail "estado de release ausente: $release_state"
app="$archive/Products/Applications/Resenha.app"
[[ -d "$app" ]] || fail "Resenha.app ausente no archive"
archive_info="$app/Contents/Info.plist"
[[ "$(plutil -extract CFBundleIdentifier raw "$archive_info")" == br.com.luisroquette.Resenha ]] || fail "bundle ID arquivado"
archive_version="$(plutil -extract CFBundleShortVersionString raw "$archive_info")"
archive_build="$(plutil -extract CFBundleVersion raw "$archive_info")"
candidate_version="$(plutil -extract candidate.version raw "$release_state")"
candidate_commit="$(plutil -extract candidate.sourceCommit raw "$release_state" 2>/dev/null || true)"
minimum_build="$(plutil -extract candidate.minimumBuild raw "$release_state")"
submitted_build="$(plutil -extract submitted.build raw "$release_state")"
[[ "$archive_version" == "$source_version" ]] || fail "versão do archive ($archive_version) diverge da fonte ($source_version)"
[[ "$archive_version" == "$candidate_version" ]] || fail "versão do archive diverge do candidato ($candidate_version)"
[[ "$archive_build" == "$source_build" ]] || fail "build do archive ($archive_build) diverge da fonte ($source_build)"
archive_commit="$(plutil -extract ResenhaSourceCommit raw "$archive_info" 2>/dev/null || true)"
[[ "$archive_commit" == "$candidate_commit" ]] \
  || fail "source commit do archive diverge do candidato"
validate_release_source_commit "$project_root" "$archive_commit" \
  || fail "source commit do archive não reproduz as fontes relevantes"
(( archive_build >= minimum_build )) || fail "build $archive_build abaixo do mínimo $minimum_build"
(( archive_build > submitted_build )) || fail "build $archive_build não supera o submetido $submitted_build"
[[ "$(plutil -extract ITSAppUsesNonExemptEncryption raw "$archive_info" 2>/dev/null || true)" == false ]] || fail "archive precisa ser refeito com export compliance"
file "$app/Contents/MacOS/Resenha" | grep -q 'arm64' || fail "binário não é arm64"
"$project_root/Scripts/validate-app-store-binary-boundary.sh" "$app/Contents/MacOS/Resenha"
codesign --verify --deep --strict "$app" || fail "assinatura inválida"
codesign -d --entitlements :- "$app" >"$entitlements" 2>/dev/null
[[ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "$entitlements")" == true ]] || fail "App Sandbox ausente"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.device.audio-input' "$entitlements")" == true ]] || fail "audio-input ausente"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.network.client' "$entitlements")" == true ]] || fail "network client ausente"
[[ "$(plutil -p "$entitlements" | grep -c ' => ')" == 3 ]] \
  || fail "archive contém entitlement adicional"
[[ -f "$app/Contents/Resources/PrivacyInfo.xcprivacy" ]] || fail "PrivacyInfo.xcprivacy ausente"
for notice in THIRD_PARTY_NOTICES.md LICENSE-whisper.cpp.txt LICENSE-OpenAI-Whisper.txt; do
  [[ -f "$app/Contents/Resources/$notice" ]] || fail "aviso/licença ausente: $notice"
done
grep -a -F -q 'WHISPER_MODEL_PATH' "$app/Contents/MacOS/Resenha" \
  && fail "override de modelo presente no binário Release"
pass "archive $archive_version ($archive_build), source ${archive_commit[1,12]}, arm64, assinado e com privacy manifest"

print "Pacote da App Store validado."
