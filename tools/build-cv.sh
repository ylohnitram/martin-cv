#!/usr/bin/env bash
# Render cv.html to Martin_Holy_CV.pdf with headless Chrome.
# Flatpak Chrome cannot read ~/git, so the page is staged under ~/Downloads.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
out="$repo/Martin_Holy_CV.pdf"
stage="$(mktemp -d "$HOME/Downloads/cv-build.XXXXXX")"
trap 'rm -rf "$stage"' EXIT

cp "$repo/cv.html" "$stage/cv.html"

if command -v google-chrome >/dev/null 2>&1; then
  chrome=(google-chrome)
elif command -v chromium >/dev/null 2>&1; then
  chrome=(chromium)
else
  chrome=(flatpak run com.google.Chrome)
fi

"${chrome[@]}" --headless --disable-gpu --no-sandbox \
  --no-pdf-header-footer \
  --print-to-pdf="$stage/cv.pdf" \
  "file://$stage/cv.html" 2>/dev/null

mv "$stage/cv.pdf" "$out"
echo "wrote $out"
