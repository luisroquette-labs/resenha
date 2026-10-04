#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
version="${RESENHA_VERSION:-1.0.0}"
build_number="${RESENHA_BUILD_NUMBER:-1}"
identity="${RESENHA_SIGNING_IDENTITY:-Developer ID Application: luis roquette (S3YCFYY8SC)}"
team_id="${RESENHA_TEAM_ID:-S3YCFYY8SC}"
output_root="${RESENHA_OUTPUT_DIR:-$project_root/build/direct}"
output_root="${output_root:A}"
archive="$output_root/Resenha-$version-b$build_number.xcarchive"
export_dir="$output_root/export"
staging="$output_root/dmg-root"
dmg="$output_root/Resenha-$version-arm64.dmg"

fail() { print -u2 "ERRO: $*"; exit 1; }
[[ "$version" == <->.<->.<-> ]] || fail "RESENHA_VERSION deve usar x.y.z"
[[ "$build_number" == <-> ]] || fail "RESENHA_BUILD_NUMBER deve ser inteiro"
[[ "$output_root" != "/" && "$output_root" != "$HOME" && "$output_root" != "$project_root" ]] || fail "diretório de saída inseguro: $output_root"
[[ -f "$project_root/WhisperKey.xcodeproj/project.pbxproj" ]] || fail "projeto Xcode ausente"
security find-identity -v -p codesigning | grep -Fq "\"$identity\"" || fail "certificado ausente: $identity"
signing_hash="$(security find-identity -v -p codesigning | awk -v name="\"$identity\"" 'index($0, name) { print $2; exit }')"
[[ "$signing_hash" =~ '^[[:xdigit:]]{40}$' ]] || fail "hash do certificado não encontrado"

mkdir -p "$output_root"
rm -rf "$archive" "$export_dir" "$staging"
rm -f "$dmg"

xcodebuild \
  -project "$project_root/WhisperKey.xcodeproj" \
  -scheme WhisperKey \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$archive" \
  archive \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$signing_hash" \
  DEVELOPMENT_TEAM="$team_id" \
  MARKETING_VERSION="$version" \
  CURRENT_PROJECT_VERSION="$build_number" \
  OTHER_CODE_SIGN_FLAGS="--timestamp"

xcodebuild \
  -exportArchive \
  -archivePath "$archive" \
  -exportPath "$export_dir" \
  -exportOptionsPlist "$project_root/Config/ExportOptions-DeveloperID.plist"

app="$export_dir/Resenha.app"
[[ -d "$app" ]] || fail "Resenha.app não foi exportado"
codesign --verify --deep --strict --verbose=2 "$app"

mkdir -p "$staging"
ditto "$app" "$staging/Resenha.app"
ln -s /Applications "$staging/Applications"
hdiutil create \
  -volname "Resenha" \
  -srcfolder "$staging" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  "$dmg"
codesign --force --sign "$signing_hash" --timestamp "$dmg"

"$project_root/Scripts/validate-release-dmg.sh" "$dmg" --before-notarization
shasum -a 256 "$dmg" > "$dmg.sha256"
print "DMG assinado: $dmg"
print "Próximo: Scripts/notarize-release-dmg.sh '$dmg'"
