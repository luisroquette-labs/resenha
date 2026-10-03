#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
archive="${1:-$project_root/build/archive/Resenha-1.0.0-b1.xcarchive}"
screenshots="$project_root/AppStore/screenshots/pt-BR"
metadata="$project_root/AppStore/metadata/pt-BR.md"
info_source="$project_root/Config/ResenhaStore-Info.plist"

fail() { print -u2 "FALHOU: $*"; exit 1; }
pass() { print "PASS: $*"; }

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
app="$archive/Products/Applications/Resenha.app"
[[ -d "$app" ]] || fail "Resenha.app ausente no archive"
archive_info="$app/Contents/Info.plist"
[[ "$(plutil -extract CFBundleIdentifier raw "$archive_info")" == br.com.luisroquette.Resenha ]] || fail "bundle ID arquivado"
[[ "$(plutil -extract CFBundleShortVersionString raw "$archive_info")" == 1.0.0 ]] || fail "versão arquivada"
[[ "$(plutil -extract CFBundleVersion raw "$archive_info")" == 1 ]] || fail "build arquivado"
[[ "$(plutil -extract ITSAppUsesNonExemptEncryption raw "$archive_info" 2>/dev/null || true)" == false ]] || fail "archive precisa ser refeito com export compliance"
file "$app/Contents/MacOS/Resenha" | grep -q 'arm64' || fail "binário não é arm64"
codesign --verify --deep --strict "$app" || fail "assinatura inválida"
[[ -f "$app/Contents/Resources/PrivacyInfo.xcprivacy" ]] || fail "PrivacyInfo.xcprivacy ausente"
pass "archive 1.0.0 (1), arm64, assinado e com privacy manifest"

print "Pacote da App Store validado."
