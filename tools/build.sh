#!/usr/bin/env bash
# Build every release target into build/. Stops on the first failure.
#   tools/build.sh            import, probe, export Linux + Windows + Web, zip for upload
# Needs Godot 4.7.1 with export templates. Set GODOT to override the binary.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$HOME/bin/godot}"
GAME="$ROOT/game"
OUT="$ROOT/build"
VERSION="$(grep '^config/version=' "$GAME/project.godot" | cut -d'"' -f2)"

echo "== Gunship Ace $VERSION"
"$GODOT" --headless --path "$GAME" --import >/dev/null 2>&1 || true

echo "== probe"
"$GODOT" --headless --path "$GAME" -- --probe 2>&1 | grep -E "^FAIL|^probe" || true
"$GODOT" --headless --path "$GAME" -- --probe >/dev/null 2>&1 || { echo "probe failed"; exit 1; }

rm -rf "$OUT/linux" "$OUT/windows" "$OUT/web" "$OUT"/*.zip
mkdir -p "$OUT/linux" "$OUT/windows" "$OUT/web"

echo "== export"
"$GODOT" --headless --path "$GAME" --export-release "Linux" "$OUT/linux/GunshipAce.x86_64" >/dev/null 2>&1
"$GODOT" --headless --path "$GAME" --export-release "Windows" "$OUT/windows/GunshipAce.exe" >/dev/null 2>&1
"$GODOT" --headless --path "$GAME" --export-release "Web" "$OUT/web/index.html" >/dev/null 2>&1
for f in "$OUT/linux/GunshipAce.x86_64" "$OUT/windows/GunshipAce.exe" "$OUT/web/index.html" "$OUT/web/index.pck"; do
  [ -s "$f" ] || { echo "missing $f"; exit 1; }
done

echo "== exported Linux build self-test"
"$OUT/linux/GunshipAce.x86_64" --headless -- --probe >/dev/null 2>&1 || { echo "exported build failed the probe"; exit 1; }

echo "== notices"
"$GODOT" --headless --path "$GAME" -- --licenses "$OUT/THIRD_PARTY.txt" >/dev/null 2>&1
for d in linux windows web; do
  cp "$OUT/THIRD_PARTY.txt" "$OUT/$d/"
  cp "$GAME/ui/fonts/OFL-PressStart2P.txt" "$OUT/$d/FONT_LICENSE_OFL_PressStart2P.txt"
  cp "$ROOT/docs/PLAYER_README.txt" "$OUT/$d/README.txt"
done

echo "== zip"
(cd "$OUT/linux" && python3 -m zipfile -c "$OUT/GunshipAce-$VERSION-linux.zip" *)
(cd "$OUT/windows" && python3 -m zipfile -c "$OUT/GunshipAce-$VERSION-windows.zip" *)
(cd "$OUT/web" && python3 -m zipfile -c "$OUT/GunshipAce-$VERSION-web.zip" *)
ls -lh "$OUT"/*.zip
echo "== done"
