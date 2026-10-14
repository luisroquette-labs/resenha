#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
fixture_root="${1:-${RESENHA_UI_FIXTURE_ROOT:-${TMPDIR:-/tmp}/ResenhaTests/ui-fixtures}}"
output_root="$project_root/site/assets/product"
social_root="$project_root/site/assets/social"
work_root="$(mktemp -d "${TMPDIR:-/tmp}/resenha-site-media.XXXXXX")"
trap 'mv "$work_root" "$HOME/.Trash/resenha-site-media-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true' EXIT

for tool in magick ffmpeg ffprobe; do
  command -v "$tool" >/dev/null || { print -u2 "$tool não encontrado"; exit 1; }
done

required=(hud-listening-light hud-listening-silence-light hud-listening-decay-light
  hud-transcribing-light hud-inserting-light settings-general-light settings-shortcut-light
  settings-sounds-light settings-audio-light settings-transcription-light settings-about-light
  settings-interaction-general settings-interaction-shortcut settings-interaction-sounds-angelic
  settings-interaction-sounds-query settings-interaction-sounds-favorite
  settings-interaction-sounds-favorites-only)
for fixture in $required; do
  test -f "$fixture_root/$fixture.png" || { print -u2 "Fixture ausente: $fixture_root/$fixture.png"; exit 1; }
done

mkdir -p "$output_root" "$social_root" "$work_root/flow" "$work_root/settings"
font_body="/System/Library/Fonts/Supplemental/Avenir Next.ttc"
font_serif="/System/Library/Fonts/Supplemental/Georgia.ttf"
test -f "$font_body" || font_body="/System/Library/Fonts/Helvetica.ttc"
test -f "$font_serif" || font_serif="$font_body"
mark="$project_root/AppStore/brand/mark/resenha-mark-ink-1024.png"
icon="$project_root/AppStore/brand/app-icon/resenha-app-icon-1024.png"

settings=(general shortcut sounds audio transcription about)
for pane in $settings; do
  magick "$fixture_root/settings-$pane-light.png" -resize '1520x1120>' -define webp:lossless=true \
    "$output_root/settings-$pane.webp"
done

# First-party social card with truthful release copy.
magick -size 1200x630 xc:'#f1eee4' \
  -fill '#e4e8dc' -stroke none -draw 'circle 1110,60 1420,60' \
  -fill none -stroke '#4f7e7440' -strokewidth 3 \
  -draw 'circle 1090,70 1230,70 circle 1090,70 1300,70 circle 1090,70 1370,70' \
  \( "$icon" -resize 170x170 \) -geometry +75+70 -composite \
  -fill '#171917' -font "$font_body" -pointsize 56 -weight 700 -annotate +270+170 'resenha.' \
  -fill '#171917' -font "$font_serif" -pointsize 76 -weight 700 -annotate +76+340 'Sua voz, em qualquer campo.' \
  -fill '#4f7e74' -font "$font_body" -pointsize 30 -weight 600 -annotate +80+430 'DITADO LOCAL · GRÁTIS · CÓDIGO ABERTO' \
  -fill '#555b55' -font "$font_body" -pointsize 25 -annotate +80+500 'SwiftUI + whisper.cpp para Apple Silicon' \
  -background '#f1eee4' -alpha remove -alpha off "$social_root/resenha-og.png"

magick -size 1440x900 xc:'#f1eee4' \
  -fill '#f8f6ef' -stroke '#c9c8bf' -strokewidth 2 -draw 'roundrectangle 108,78 1332,822 26,26' \
  -fill '#eeece4' -stroke none -draw 'roundrectangle 108,78 1332,148 26,26' \
  -fill '#b8b7b0' -draw 'circle 145,113 151,113 circle 171,113 177,113 circle 197,113 203,113' \
  -fill '#74776f' -font "$font_body" -pointsize 18 -gravity north -annotate +0+101 'Rascunho — Resenha' \
  -fill '#4f7e74' -font "$font_body" -pointsize 18 -gravity northwest -annotate +170+205 'MENSAGEM' \
  -fill '#666960' -font "$font_body" -pointsize 18 -gravity northwest -annotate +170+442 'O áudio permanece neste Mac.' \
  \( "$mark" -resize 58x58 \) -gravity northeast -geometry +155+182 -composite \
  "$work_root/editor.png"

sentence='Éric, avise ao Luís que a COESA atualizou o README da Resenha.'
words=(${(z)sentence})

# 96 unique frames: moving cursor, visible key press, responsive native HUD
# fixtures, and progressive insertion. This is a disclosed local demonstration.
for frame in {0..95}; do
  file="$work_root/flow/$(printf '%03d' $frame).png"
  cursor_x=$((1180 - (frame < 12 ? frame * 76 : 912)))
  cursor_y=$((690 - (frame < 12 ? frame * 30 : 360)))
  cp "$work_root/editor.png" "$file"

  if (( frame >= 12 && frame < 54 )); then
    waveform=(hud-listening-silence-light hud-listening-light hud-listening-decay-light)
    hud="${waveform[$((frame % 3 + 1))]}.png"
    magick "$file" \
      -fill '#dce8e3' -stroke '#4f7e74' -strokewidth 2 -draw 'roundrectangle 170,510 490,574 16,16' \
      -fill '#284e47' -font "$font_body" -pointsize 18 -weight 700 -annotate +190+550 'SHIFT + COMMAND + E' \
      \( "$fixture_root/$hud" -resize 680x144 \) -gravity south -geometry +0+68 -composite "$file"
  elif (( frame >= 54 && frame < 68 )); then
    magick "$file" \( "$fixture_root/hud-transcribing-light.png" -resize 680x144 \) \
      -gravity south -geometry +0+68 -composite "$file"
  elif (( frame >= 68 )); then
    count=$(( (frame - 67) * ${#words} / 28 ))
    (( count < 1 )) && count=1
    (( count > ${#words} )) && count=${#words}
    typed="${(j: :)words[1,$count]}"
    magick "$file" \
      \( -background none -fill '#101114' -font "$font_serif" -pointsize 42 -size 990x150 caption:"$typed" \) \
      -geometry +170+274 -composite \
      \( "$fixture_root/hud-inserting-light.png" -resize 680x144 \) -gravity south -geometry +0+68 -composite "$file"
  else
    magick "$file" -fill '#101114' -draw 'rectangle 170,275 173,331' "$file"
  fi

  pulse=$((frame % 12))
  magick "$file" -fill '#ffffff' -stroke '#171917' -strokewidth 2 \
    -draw "polygon $cursor_x,$cursor_y $((cursor_x+3)),$((cursor_y+27)) $((cursor_x+10)),$((cursor_y+19)) $((cursor_x+17)),$((cursor_y+31)) $((cursor_x+23)),$((cursor_y+27)) $((cursor_x+16)),$((cursor_y+16)) $((cursor_x+28)),$((cursor_y+14))" \
    -fill '#4f7e74' -stroke none -draw "circle $cursor_x,$cursor_y $((cursor_x + 3 + pulse / 3)),$cursor_y" "$file"
done

ffmpeg -hide_banner -loglevel error -y -framerate 12 -i "$work_root/flow/%03d.png" \
  -vf 'fps=30,format=yuv420p' -an -c:v libx264 -preset slow -crf 21 -movflags +faststart \
  "$output_root/resenha-flow.mp4"
magick "$work_root/flow/018.png" -quality 92 "$output_root/resenha-flow-poster.webp"

# A continuous, truthful interaction uses native SwiftUI renders for every
# semantic state: navigation, typed search, favorite toggle and favorites-only.
interaction=(general shortcut sounds-angelic sounds-query sounds-favorite sounds-favorites-only)
cursor_targets_x=(190 190 520 605 1170 1040)
cursor_targets_y=(210 264 250 250 390 250)
for frame in {0..119}; do
  scene_index=$((frame / 20 + 1))
  local_frame=$((frame % 20))
  scene="${interaction[$scene_index]}"
  source_image="$fixture_root/settings-interaction-$scene.png"
  cursor_x=$((210 + (cursor_targets_x[$scene_index] - 210) * local_frame / 19))
  cursor_y=$((690 + (cursor_targets_y[$scene_index] - 690) * local_frame / 19))
  file="$work_root/settings/$(printf '%03d' $frame).png"
  state_image="$work_root/settings/state-$(printf '%03d' $frame).png"
  if (( local_frame >= 15 && scene_index < ${#interaction} )); then
    next_scene="${interaction[$((scene_index + 1))]}"
    blend=$(( (local_frame - 14) * 16 ))
    magick "$source_image" "$fixture_root/settings-interaction-$next_scene.png" \
      -define compose:args="$blend" -compose blend -composite "$state_image"
  else
    magick "$source_image" "$state_image"
  fi
  halo=$((local_frame >= 13 && local_frame <= 17 ? 22 - (local_frame - 15) * (local_frame - 15) * 2 : 7))
  magick -size 1440x900 xc:'#f1eee4' \
    \( "$state_image" -resize '1221x900>' \) -gravity center -composite \
    -fill '#4f7e7428' -stroke '#4f7e74' -strokewidth 2 \
    -draw "circle $cursor_x,$cursor_y $((cursor_x + halo)),$cursor_y" \
    -fill '#ffffff' -stroke '#171917' -strokewidth 2 \
    -draw "polygon $cursor_x,$cursor_y $((cursor_x+3)),$((cursor_y+27)) $((cursor_x+10)),$((cursor_y+19)) $((cursor_x+17)),$((cursor_y+31)) $((cursor_x+23)),$((cursor_y+27)) $((cursor_x+16)),$((cursor_y+16)) $((cursor_x+28)),$((cursor_y+14))" \
    "$file"
done
ffmpeg -hide_banner -loglevel error -y -framerate 15 -i "$work_root/settings/%03d.png" \
  -vf 'fps=30,format=yuv420p' -an -c:v libx264 -preset slow -crf 20 -movflags +faststart \
  "$output_root/resenha-settings.mp4"

manifest="$output_root/resenha-settings-scenes.json"
printf '{\n  "fps": 30,\n  "duration": 8,\n  "scenes": [\n' > "$manifest"
for index in {1..${#interaction}}; do
  scene="${interaction[$index]}"
  hash="$(shasum -a 256 "$fixture_root/settings-interaction-$scene.png" | awk '{print $1}')"
  timestamp="$(awk -v scene_number="$index" 'BEGIN { printf "%.3f", ((scene_number - 1) * 4 / 3) + 0.5 }')"
  separator=','
  (( index == ${#interaction} )) && separator=''
  printf '    {"name":"%s","sampleTime":%s,"fixtureSHA256":"%s"}%s\n' \
    "$scene" "$timestamp" "$hash" "$separator" >> "$manifest"
done
printf '  ]\n}\n' >> "$manifest"

for video in "$output_root"/*.mp4; do
  ffprobe -v error -select_streams v:0 -show_entries stream=width,height,nb_frames,duration \
    -of default=noprint_wrappers=1 "$video"
done
