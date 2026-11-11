#!/bin/zsh
# Copies AFK Gains into the WoW Forever AddOns folder.
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
DST="/Applications/World of Warcraft/_forever_/Interface/AddOns/AFKGains"
mkdir -p "$DST/Media/Rings"
cp "$SRC/AFKGains.toc" "$SRC/LICENSE" "$SRC/README.md" "$SRC/README.ru.md" "$DST/"
cp "$SRC/Media/icon.tga" "$DST/Media/"
cp "$SRC"/Media/Rings/*.tga "$DST/Media/Rings/"
grep -v '^##' "$SRC/AFKGains.toc" | tr -d '\r' | while read -r file; do
  [ -z "$file" ] && continue
  cp "$SRC/$file" "$DST/$file"
done
echo "AFK Gains installed to $DST. Type /reload in the game."
