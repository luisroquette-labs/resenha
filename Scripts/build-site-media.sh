#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
fixture_root="${1:-$HOME/Library/Containers/br.com.luisroquette.Resenha/Data/tmp/ResenhaTests/ui-fixtures}"
output_root="$project_root/site/assets/product"
work_root="$(mktemp -d "${TMPDIR:-/tmp}/resenha-site-media.XXXXXX")"
trap 'mv "$work_root" "$HOME/.Trash/resenha-site-media-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true' EXIT

for tool in magick ffmpeg; do
  command -v "$tool" >/dev/null || { print -u2 "$tool não encontrado"; exit 1; }
done

mkdir -p "$output_root"

settings=(general shortcut sounds audio transcription about)
for pane in $settings; do
  source="$fixture_root/settings-$pane-light.png"
  test -f "$source" || { print -u2 "Fixture ausente: $source"; exit 1; }
  magick "$source" -resize '1520x1120>' -define webp:lossless=true \
    "$output_root/settings-$pane.webp"
done

mark="$project_root/AppStore/brand/mark/resenha-mark-ink-1024.png"
font_body="/System/Library/Fonts/Supplemental/Avenir Next.ttc"
font_serif="/System/Library/Fonts/Supplemental/Georgia.ttf"
test -f "$font_body" || font_body="/System/Library/Fonts/Helvetica.ttc"
test -f "$font_serif" || font_serif="$font_body"

function demo_scene() {
  local state="$1"
  local hud="$2"
  local line_one="$3"
  local line_two="$4"
  local helper="$5"
  local destination="$work_root/demo-$state.png"
  magick -size 1440x900 xc:'#f1eee4' \
    -fill '#f8f6ef' -stroke '#c9c8bf' -strokewidth 2 -draw 'roundrectangle 108,78 1332,822 26,26' \
    -fill '#eeece4' -stroke none -draw 'roundrectangle 108,78 1332,148 26,26' \
    -fill '#b8b7b0' -draw 'circle 145,113 151,113 circle 171,113 177,113 circle 197,113 203,113' \
    -fill '#74776f' -font "$font_body" -pointsize 18 -gravity north -annotate +0+101 'Rascunho — Resenha' \
    -fill '#4f7e74' -font "$font_body" -pointsize 18 -gravity northwest -annotate +170+205 'NOTA DE VOZ / 001' \
    -fill '#101114' -font "$font_serif" -pointsize 50 -gravity northwest \
    -annotate +170+274 "$line_one" \
    -annotate +170+344 "$line_two" \
    -fill '#666960' -font "$font_body" -pointsize 18 -gravity northwest -annotate +170+442 "$helper" \
    -fill '#4f7e74' -font "$font_body" -pointsize 15 -gravity southwest -annotate +170+128 "$state" \
    \( "$mark" -resize 58x58 \) -gravity northeast -geometry +155+182 -composite \
    \( "$fixture_root/$hud" -resize '680x144>' \) -gravity south -geometry +0+86 -composite \
    "$destination"
}

demo_scene 'OUVINDO' 'hud-listening-light.png' '|' '' 'Fale normalmente. O áudio permanece neste Mac.'
demo_scene 'TRANSCREVENDO' 'hud-transcribing-light.png' 'Processando no Mac…' '' 'whisper.cpp + Metal'
demo_scene 'TEXTO INSERIDO' 'hud-inserting-light.png' 'Éric, avise ao Luís que a COESA atualizou o README' 'da Resenha e rodou o benchmark do whisper.cpp.' 'Entrega confirmada para quarta-feira, às 17h00.'

ffmpeg -hide_banner -loglevel error -y \
  -loop 1 -t 3 -i "$work_root/demo-OUVINDO.png" \
  -loop 1 -t 2 -i "$work_root/demo-TRANSCREVENDO.png" \
  -loop 1 -t 3 -i "$work_root/demo-TEXTO INSERIDO.png" \
  -filter_complex "[0:v]fps=30,format=yuv420p,setpts=PTS-STARTPTS[v0];[1:v]fps=30,format=yuv420p,setpts=PTS-STARTPTS[v1];[2:v]fps=30,format=yuv420p,setpts=PTS-STARTPTS[v2];[v0][v1]xfade=transition=wipeleft:duration=0.35:offset=2.65[x1];[x1][v2]xfade=transition=wipeleft:duration=0.35:offset=4.3,format=yuv420p[v]" \
  -map '[v]' -an -c:v libx264 -preset slow -crf 21 -movflags +faststart "$output_root/resenha-flow.mp4"

ffmpeg -hide_banner -loglevel error -y \
  -loop 1 -t 2.6 -i "$fixture_root/settings-general-light.png" \
  -loop 1 -t 2.6 -i "$fixture_root/settings-shortcut-light.png" \
  -loop 1 -t 2.6 -i "$fixture_root/settings-sounds-light.png" \
  -loop 1 -t 2.6 -i "$fixture_root/settings-transcription-light.png" \
  -filter_complex "[0:v]scale=1221:900:force_original_aspect_ratio=decrease,pad=1440:900:(ow-iw)/2:(oh-ih)/2:color=0xf1eee4,fps=30,format=yuv420p,setpts=PTS-STARTPTS[v0];[1:v]scale=1221:900:force_original_aspect_ratio=decrease,pad=1440:900:(ow-iw)/2:(oh-ih)/2:color=0xf1eee4,fps=30,format=yuv420p,setpts=PTS-STARTPTS[v1];[2:v]scale=1221:900:force_original_aspect_ratio=decrease,pad=1440:900:(ow-iw)/2:(oh-ih)/2:color=0xf1eee4,fps=30,format=yuv420p,setpts=PTS-STARTPTS[v2];[3:v]scale=1221:900:force_original_aspect_ratio=decrease,pad=1440:900:(ow-iw)/2:(oh-ih)/2:color=0xf1eee4,fps=30,format=yuv420p,setpts=PTS-STARTPTS[v3];[v0][v1]xfade=transition=wipeleft:duration=0.35:offset=2.25[x1];[x1][v2]xfade=transition=wipeleft:duration=0.35:offset=4.5[x2];[x2][v3]xfade=transition=wipeleft:duration=0.35:offset=6.75,format=yuv420p[v]" \
  -map '[v]' -an -c:v libx264 -preset slow -crf 20 -movflags +faststart "$output_root/resenha-settings.mp4"

magick "$work_root/demo-OUVINDO.png" -quality 92 "$output_root/resenha-flow-poster.webp"

for video in "$output_root"/*.mp4; do
  ffprobe -v error -select_streams v:0 -show_entries stream=width,height,duration \
    -of default=noprint_wrappers=1 "$video"
done
