#!/bin/zsh
# Copies Campfire into the WoW Forever AddOns folder.
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
DST="/Applications/World of Warcraft/_forever_/Interface/AddOns/Campfire"
mkdir -p "$DST/Media/Rings"
cp "$SRC/Campfire.toc" "$SRC/LICENSE" "$SRC/README.md" "$DST/"
cp "$SRC/Media/icon.tga" "$DST/Media/"
cp "$SRC"/Media/Rings/*.tga "$DST/Media/Rings/"
grep -v '^##' "$SRC/Campfire.toc" | tr -d '\r' | while read -r file; do
  [ -z "$file" ] && continue
  cp "$SRC/$file" "$DST/$file"
done
echo "Campfire installed to $DST. Type /reload in the game."
