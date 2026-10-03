#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
SOURCE="$ROOT/docs/brand/concepts"
ASSETS="$ROOT/Sources/WhisperKey/Assets.xcassets/AppIcon.appiconset"
OUTPUT="$ROOT/AppStore/brand"
TEMP_OUTPUT="$(mktemp -d)"

mkdir -p "$OUTPUT/app-icon" "$OUTPUT/mark" "$OUTPUT/lockup"

for size in 16 32 64 128 256 512 1024; do
  cp "$ASSETS/app-icon-$size.png" "$OUTPUT/app-icon/resenha-app-icon-$size.png"
done

cp "$SOURCE/resenha-mark-v2.svg" "$OUTPUT/mark/resenha-mark-ink.svg"
cp "$SOURCE/resenha-lockup-v2.svg" "$OUTPUT/lockup/resenha-lockup-ink.svg"

qlmanage -t -s 4096 -o "$TEMP_OUTPUT" "$SOURCE/resenha-mark-v2.svg" >/dev/null 2>&1
qlmanage -t -s 4096 -o "$TEMP_OUTPUT" "$SOURCE/resenha-lockup-v2.svg" >/dev/null 2>&1

magick "$TEMP_OUTPUT/resenha-mark-v2.svg.png" -alpha on -fuzz 3% -transparent white \
  -trim +repage -resize 880x880 -gravity center -background none -extent 1024x1024 \
  "$OUTPUT/mark/resenha-mark-ink-1024.png"
magick "$OUTPUT/mark/resenha-mark-ink-1024.png" -channel RGB \
  -fill '#F7F6F2' -colorize 100 "$OUTPUT/mark/resenha-mark-light-1024.png"
magick "$TEMP_OUTPUT/resenha-lockup-v2.svg.png" -alpha on -fuzz 3% -transparent white \
  -trim +repage -resize 2200x500 -gravity center -background none -extent 2400x600 \
  "$OUTPUT/lockup/resenha-lockup-ink-2400.png"
magick "$OUTPUT/lockup/resenha-lockup-ink-2400.png" -channel RGB \
  -fill '#F7F6F2' -colorize 100 "$OUTPUT/lockup/resenha-lockup-light-2400.png"

for file in "$OUTPUT"/**/*.png; do
  magick identify -quiet "$file" >/dev/null
done

/usr/bin/trash "$TEMP_OUTPUT"

echo "Brand exports ready at $OUTPUT"
