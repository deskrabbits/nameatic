#!/bin/bash
# Renders Icon/icon.svg to Icon/AppIcon.icns using only built-in macOS tools.
set -euo pipefail
cd "$(dirname "$0")/.."

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Quick Look rasterizes the SVG (no external deps needed).
qlmanage -t -s 1024 -o "$WORK" Icon/icon.svg >/dev/null
MASTER="$WORK/icon.svg.png"
[ -f "$MASTER" ] || { echo "qlmanage produced no PNG" >&2; exit 1; }

ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$MASTER" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$MASTER" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o Icon/AppIcon.icns
echo "Wrote Icon/AppIcon.icns"
