#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
source "$project_root/Scripts/validate-release-dmg.sh"
source_sha="$(git -C "$project_root" rev-parse HEAD)"
source_diff="$(git -C "$project_root" diff --binary HEAD -- Sources Config project.yml WhisperKey.xcodeproj | shasum -a 256 | awk '{print $1}')"
version="${RESENHA_VERSION:-1.1.0}"
build_number="${RESENHA_BUILD_NUMBER:-20261028}"
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

[[ ! -e "$archive" && ! -e "$export_dir" && ! -e "$staging" && ! -e "$dmg" ]] || fail "saída já existe; escolha RESENHA_OUTPUT_DIR novo para preservar artefatos"
mkdir -p "$output_root"

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
[[ "$(git -C "$project_root" rev-parse HEAD)" == "$source_sha" ]] || fail "HEAD mudou durante o build"
[[ "$(git -C "$project_root" diff --binary HEAD -- Sources Config project.yml WhisperKey.xcodeproj | shasum -a 256 | awk '{print $1}')" == "$source_diff" ]] || fail "fontes mudaram durante o build"
provenance="$app/Contents/Resources/ResenhaBuild.plist"
plutil -create xml1 "$provenance"
plutil -insert SourceSHA -string "$source_sha" "$provenance"
plutil -insert SourceDiffSHA256 -string "$source_diff" "$provenance"
plutil -insert Configuration -string Release "$provenance"
codesign --force --sign "$signing_hash" --options runtime --timestamp --preserve-metadata=entitlements,requirements "$app"
validate_release_app "$app" "$source_sha"

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
(cd "$output_root" && shasum -a 256 "${dmg:t}" > "${dmg:t}.sha256")
print "DMG assinado: $dmg"
print "Próximo: Scripts/notarize-release-dmg.sh '$dmg'"
