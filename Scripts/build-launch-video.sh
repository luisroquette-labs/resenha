#!/bin/zsh
set -euo pipefail

root="${0:A:h:h}"
assets="$root/site/assets/product"
brand="$root/site/assets/brand"
font="/System/Library/Fonts/Avenir Next.ttc"
serif="/System/Library/Fonts/Supplemental/Baskerville.ttc"
wide="$assets/resenha-launch-16x9.mp4"
vertical="$assets/resenha-launch-9x16.mp4"
work="$(mktemp -d /tmp/resenha-launch-video.XXXXXX)"
trap 'rm -rf "$work"' EXIT

[[ -f "$font" && -f "$serif" ]] || { print -u2 "Fontes do macOS ausentes"; exit 1; }
command -v magick >/dev/null || { print -u2 "ImageMagick ausente"; exit 1; }

magick -size 1920x1080 xc:'#f1eee4' \
  -font "$font" -fill '#42685f' -pointsize 34 -kerning 8 -gravity north -annotate +0+220 'RESENHA' \
  -font "$serif" -fill '#101114' -pointsize 92 -kerning 0 -gravity center -annotate +0-35 'Sua voz, em qualquer campo.' \
  -font "$font" -fill '#666960' -pointsize 27 -kerning 4 -gravity center -annotate +0+112 'LOCAL  ·  GRÁTIS  ·  OPEN SOURCE' \
  "$work/title.png"

magick -size 1200x630 xc:'#f1eee4' \
  -font "$font" -fill '#42685f' -pointsize 25 -kerning 7 -gravity northwest -annotate +72+70 'RESENHA' \
  -font "$serif" -fill '#101114' -pointsize 72 -gravity northwest -annotate +72+160 'Tipo o Wispr,' \
  -fill '#42685f' -annotate +72+250 'mas grátis e com JEV.' \
  -font "$font" -fill '#666960' -pointsize 22 -kerning 2 -annotate +76+390 'DITADO LOCAL PARA MAC · OPEN SOURCE' \
  \( "$brand/resenha-app-icon.png" -resize 228x228 \) -gravity east -geometry +85+0 -composite \
  "$assets/resenha-social-card.png"

magick -size 1920x1080 xc:none \
  -fill '#171b1ae0' -draw 'roundrectangle 90,72 820,180 18,18' \
  -font "$font" -fill '#f8f6ef' -pointsize 39 -kerning 3 -gravity northwest -annotate +126+100 'SEGURE. FALE. SOLTE.' \
  "$work/flow-overlay.png"

magick -size 1920x1080 xc:none \
  -fill '#171b1ae0' -draw 'roundrectangle 90,72 905,180 18,18' \
  -font "$font" -fill '#f8f6ef' -pointsize 37 -kerning 2 -gravity northwest -annotate +126+101 'CONTEXTO, SOB SEU CONTROLE.' \
  "$work/settings-overlay.png"

magick -size 1920x1080 xc:none \
  -fill '#171b1aeb' -draw 'rectangle 0,820 1920,1080' \
  -font "$serif" -fill '#f8f6ef' -pointsize 70 -gravity north -annotate +0+855 'Whisper no Mac. JEV opcional.' \
  -font "$font" -fill '#91c0b5' -pointsize 26 -kerning 3 -gravity north -annotate +0+968 'O ÁUDIO NUNCA SAI DO COMPUTADOR.' \
  "$work/privacy-overlay.png"

magick -size 1920x1080 xc:'#42685f' \
  -font "$font" -fill '#f8f6ef' -pointsize 48 -gravity north -annotate +0+255 'resenha.' \
  -font "$serif" -fill '#f8f6ef' -pointsize 96 -gravity center -annotate +0-28 'Fale. Solte. Continue.' \
  -font "$font" -fill '#dce8df' -pointsize 28 -kerning 3 -gravity center -annotate +0+112 'TIPO O WISPR, MAS GRÁTIS E COM JEV.' \
  "$work/cta.png"

magick -size 1080x1920 xc:none \
  -font "$font" -fill '#91c0b5' -pointsize 42 -kerning 7 -gravity north -annotate +0+230 'RESENHA' \
  -font "$serif" -fill '#f8f6ef' -pointsize 72 -gravity north -annotate +0+325 'Fale. Solte. Continue.' \
  -font "$font" -fill '#dce8df' -pointsize 28 -kerning 2 -gravity north -annotate +0+1485 'GRÁTIS · LOCAL · OPEN SOURCE' \
  -font "$font" -fill '#f8f6ef' -pointsize 48 -gravity north -annotate +0+1565 'resenha.' \
  "$work/vertical-overlay.png"

ffmpeg -hide_banner -loglevel warning -y \
  -loop 1 -t 3.6 -i "$work/title.png" \
  -i "$assets/resenha-flow.mp4" \
  -loop 1 -t 7.3 -i "$work/flow-overlay.png" \
  -i "$assets/resenha-settings.mp4" \
  -loop 1 -t 7.6 -i "$work/settings-overlay.png" \
  -loop 1 -t 4.2 -i "$assets/settings-transcription.webp" \
  -loop 1 -t 4.2 -i "$work/privacy-overlay.png" \
  -loop 1 -t 3.8 -i "$work/cta.png" \
  -filter_complex "
    [0:v]fps=30,setsar=1,format=yuv420p,setpts=PTS-STARTPTS[t];
    [1:v]trim=duration=7.3,setpts=PTS-STARTPTS,scale=1728:1080:force_original_aspect_ratio=decrease,
      pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=0x171b1a,setsar=1[f0];
    [2:v]fps=30,format=rgba,setpts=PTS-STARTPTS[fo]; [f0][fo]overlay=0:0:shortest=1[f];
    [3:v]trim=duration=7.6,setpts=PTS-STARTPTS,scale=1728:1080:force_original_aspect_ratio=decrease,
      pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=0x171b1a,setsar=1[s0];
    [4:v]fps=30,format=rgba,setpts=PTS-STARTPTS[so]; [s0][so]overlay=0:0:shortest=1[s];
    [5:v]scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=0x171b1a,
      zoompan=z='min(zoom+0.00045,1.045)':d=126:s=1920x1080:fps=30,setsar=1[p0];
    [6:v]fps=30,format=rgba,setpts=PTS-STARTPTS[po]; [p0][po]overlay=0:0:shortest=1[p];
    [7:v]fps=30,setsar=1,format=yuv420p,setpts=PTS-STARTPTS[c];
    [t][f][s][p][c]concat=n=5:v=1:a=0,format=yuv420p[v]
  " \
  -map "[v]" -an -c:v libx264 -preset slow -crf 19 -movflags +faststart "$wide"

ffmpeg -hide_banner -loglevel warning -y -i "$wide" -loop 1 -i "$work/vertical-overlay.png" \
  -filter_complex "[0:v]scale=1080:608,pad=1080:1920:0:656:color=0x171b1a[base];[1:v]format=rgba[overlay];[base][overlay]overlay=0:0:shortest=1[v]" \
  -map "[v]" -an -c:v libx264 -preset slow -crf 20 -movflags +faststart "$vertical"

for video in "$wide" "$vertical"; do
  duration="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$video")"
  [[ "${duration%.*}" -ge 26 && "${duration%.*}" -le 28 ]] || { print -u2 "Duração inesperada: $video ($duration)"; exit 1; }
done

print "Vídeos prontos:"
print "$wide"
print "$vertical"
