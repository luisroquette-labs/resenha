#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
fixture_root="${1:-${RESENHA_UI_FIXTURE_ROOT:-${TMPDIR:-/tmp}/ResenhaTests/ui-fixtures}}"
output_root="$project_root/AppStore/screenshots/pt-BR"
work_root="$(mktemp -d "${TMPDIR:-/tmp}/resenha-app-store.XXXXXX")"
trap 'mv "$work_root" "$HOME/.Trash/resenha-app-store-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true' EXIT

command -v magick >/dev/null || { print -u2 "ImageMagick não encontrado"; exit 1; }

font_body="/System/Library/Fonts/Supplemental/Avenir Next.ttc"
font_serif="/System/Library/Fonts/Supplemental/Georgia.ttf"
test -f "$font_body" || font_body="/System/Library/Fonts/Helvetica.ttc"
test -f "$font_serif" || font_serif="$font_body"

mark="$project_root/AppStore/brand/mark/resenha-mark-ink-1024.png"
test -f "$mark" || { print -u2 "Marca ausente: $mark"; exit 1; }

required=(
  hud-listening-light.png
  hud-transcribing-light.png
  hud-inserting-light.png
  hud-failure-light.png
  settings-general-light.png
  settings-shortcut-light.png
  settings-sounds-light.png
  settings-audio-light.png
  settings-transcription-light.png
  settings-about-light.png
  settings-general-dark.png
)
for fixture in $required; do
  test -f "$fixture_root/$fixture" || { print -u2 "Fixture ausente: $fixture_root/$fixture"; exit 1; }
done

mkdir -p "$output_root"
setopt local_options null_glob
existing_screenshots=("$output_root"/*.png)
(( ${#existing_screenshots} == 0 )) || rm -f $existing_screenshots

function canvas() {
  local destination="$1"
  magick -size 2880x1800 xc:'#f1eee4' \
    -fill '#e4e8dc' -stroke none -draw 'circle 2700,90 3260,90' \
    -fill none -stroke '#7aa99c22' -strokewidth 4 \
    -draw 'circle 2700,90 2980,90 circle 2700,90 3090,90 circle 2700,90 3200,90' \
    "$destination"
}

function brand_header() {
  local source="$1"
  local destination="$2"
  magick "$source" \
    \( "$mark" -resize 88x88 \) -geometry +128+96 -composite \
    -fill '#171917' -font "$font_body" -pointsize 56 -weight 700 \
    -annotate +238+163 'resenha.' \
    -fill '#527d72' -font "$font_body" -pointsize 30 -weight 600 \
    -annotate +2460+151 '100% LOCAL' \
    "$destination"
}

function add_title() {
  local source="$1"
  local title="$2"
  local subtitle="$3"
  local destination="$4"
  magick "$source" \
    -fill '#171917' -font "$font_serif" -pointsize 116 -weight 700 \
    -gravity northwest -annotate +128+260 "$title" \
    -fill '#555b55' -font "$font_body" -pointsize 45 -weight 500 \
    -gravity northwest -annotate +132+430 "$subtitle" \
    "$destination"
}

function framed_fixture() {
  local source="$1"
  local fixture="$2"
  local geometry="$3"
  local destination="$4"
  magick "$source" \
    -fill '#15181618' -stroke none -draw 'roundrectangle 270,612 2610,1690 54,54' \
    \( "$fixture_root/$fixture" -resize '2200x1050>' \
       -bordercolor '#d7d7ce' -border 2 -alpha off \
       \( +clone -background '#11151155' -shadow 42x18+0+22 \) +swap -background none -layers merge +repage \) \
    -gravity center -geometry "$geometry" -composite \
    "$destination"
}

function settings_shot() {
  local number="$1"
  local title="$2"
  local subtitle="$3"
  local fixture="$4"
  local slug="$5"
  local base="$work_root/$slug-base.png"
  local branded="$work_root/$slug-brand.png"
  local titled="$work_root/$slug-title.png"
  canvas "$base"
  brand_header "$base" "$branded"
  add_title "$branded" "$title" "$subtitle" "$titled"
  framed_fixture "$titled" "$fixture" '+0+265' "$output_root/$number-$slug.png"
}

# 01 — real HUD over a neutral writing surface. The product UI is never redrawn.
canvas "$work_root/hero-base.png"
brand_header "$work_root/hero-base.png" "$work_root/hero-brand.png"
add_title "$work_root/hero-brand.png" 'Fale. Solte. Continue.' 'Ditado local no campo em que você já está escrevendo.' "$work_root/hero-title.png"
magick "$work_root/hero-title.png" \
  -fill '#fbfaf5' -stroke '#cbcfc5' -strokewidth 3 -draw 'roundrectangle 300,650 2580,1640 50,50' \
  -fill '#eff0e9' -stroke none -draw 'roundrectangle 300,650 2580,760 50,50' \
  -fill '#8c928a' -draw 'circle 370,705 382,705 circle 420,705 432,705 circle 470,705 482,705' \
  -fill '#527d72' -font "$font_body" -pointsize 33 -weight 600 -annotate +430+922 'MENSAGEM' \
  -fill '#1b1d1b' -font "$font_serif" -pointsize 68 -annotate +430+1060 'Éric, avise ao Luís que a COESA atualizou o README' \
  -annotate +430+1155 'da Resenha e rodou o benchmark do whisper.cpp.' \
  \( "$fixture_root/hud-listening-light.png" -resize 1080x229 \
     \( +clone -background '#11151155' -shadow 40x16+0+18 \) +swap -background none -layers merge +repage \) \
  -gravity south -geometry +0+95 -composite \
  "$output_root/01-fale-solte-continue.png"

# 02 — the actual HUD state machine.
canvas "$work_root/flow-base.png"
brand_header "$work_root/flow-base.png" "$work_root/flow-brand.png"
add_title "$work_root/flow-brand.png" 'Um gesto. Três estados.' 'O Resenha mostra exatamente quando ouvir, processar e inserir.' "$work_root/flow-title.png"
magick "$work_root/flow-title.png" \
  -fill '#527d72' -font "$font_body" -pointsize 33 -weight 700 -annotate +260+770 '01  OUVINDO' \
  -annotate +260+1110 '02  TRANSCREVENDO' \
  -annotate +260+1450 '03  INSERINDO' \
  \( "$fixture_root/hud-listening-light.png" -resize 1260x267 \) -geometry +930+620 -composite \
  \( "$fixture_root/hud-transcribing-light.png" -resize 1260x267 \) -geometry +930+960 -composite \
  \( "$fixture_root/hud-inserting-light.png" -resize 1260x267 \) -geometry +930+1300 -composite \
  "$output_root/02-tres-estados.png"

settings_shot '03' 'Seu atalho. Seu ritmo.' 'Configure a combinação global e segure para falar.' 'settings-shortcut-light.png' 'atalho-global'
settings_shot '04' 'Português sem medo do inglês.' 'PT-BR, English e Español com vocabulário pessoal.' 'settings-transcription-light.png' 'idiomas-anglicismos'
settings_shot '05' 'Seu texto continua com você.' 'Cada transcrição vai ao clipboard; o histórico local é opcional.' 'settings-general-light.png' 'clipboard-local'
settings_shot '06' 'Sua voz não sai deste Mac.' 'Whisper local, sem conta, nuvem ou backend.' 'settings-about-light.png' 'privacidade-local'
settings_shot '07' 'O microfone certo, sempre.' 'Escolha a entrada e confirme o nível antes de ditar.' 'settings-audio-light.png' 'audio'
settings_shot '08' 'Grátis. Aberto. Sem conta.' 'SwiftUI e whisper.cpp: o essencial, auditável e local.' 'settings-about-light.png' 'codigo-aberto'

# 09 — truthful recovery state, rendered by the native HUD.
canvas "$work_root/failure-base.png"
brand_header "$work_root/failure-base.png" "$work_root/failure-brand.png"
add_title "$work_root/failure-brand.png" 'Falhou? Você sabe por quê.' 'Avisos curtos mostram a causa e deixam o texto recuperável.' "$work_root/failure-title.png"
magick "$work_root/failure-title.png" \
  -fill '#fbfaf5' -stroke '#cbcfc5' -strokewidth 3 -draw 'roundrectangle 420,720 2460,1530 50,50' \
  -fill '#527d72' -font "$font_body" -pointsize 32 -weight 700 -annotate +610+920 'RECUPERAÇÃO CLARA' \
  -fill '#1b1d1b' -font "$font_serif" -pointsize 62 -annotate +610+1050 'Nada desaparece em silêncio.' \
  -fill '#5c625d' -font "$font_body" -pointsize 38 -annotate +610+1145 'Abra o menu para ver o próximo passo.' \
  \( "$fixture_root/hud-failure-light.png" -resize 1360x288 \
     \( +clone -background '#11151155' -shadow 40x16+0+18 \) +swap -background none -layers merge +repage \) \
  -gravity south -geometry +0+100 -composite \
  "$output_root/09-recuperacao.png"

# 10 — real light and dark renders prove native appearance support.
canvas "$work_root/appearance-base.png"
brand_header "$work_root/appearance-base.png" "$work_root/appearance-brand.png"
add_title "$work_root/appearance-brand.png" 'Claro, escuro, sempre Resenha.' 'A interface acompanha a aparência e os recursos de acesso do macOS.' "$work_root/appearance-title.png"
magick "$work_root/appearance-title.png" \
  -fill '#d9dad2' -stroke none -draw 'roundrectangle 100,650 2780,1690 54,54' \
  \( "$fixture_root/settings-general-light.png" -resize 1350x995 \
     -bordercolor '#d7d7ce' -border 2 \) -geometry +115+665 -composite \
  \( "$fixture_root/settings-general-dark.png" -resize 1350x995 \
     -bordercolor '#343734' -border 2 \) -geometry +1415+665 -composite \
  "$output_root/10-aparencias.png"

for image in "$output_root"/*.png; do
  magick "$image" -background '#f1eee4' -alpha remove -alpha off "$image"
  dimensions="$(sips -g pixelWidth -g pixelHeight "$image" | awk '/pixelWidth|pixelHeight/ {print $2}' | paste -sd x -)"
  channels="$(magick identify -format '%[channels]' "$image")"
  [[ "$dimensions" == '2880x1800' ]] || { print -u2 "Dimensão inválida: $image ($dimensions)"; exit 1; }
  [[ "$channels" != *a* ]] || { print -u2 "Alpha proibido: $image ($channels)"; exit 1; }
  print "${image:t}: $dimensions, $channels"
done
