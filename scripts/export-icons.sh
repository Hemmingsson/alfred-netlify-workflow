#!/bin/sh
# Export the current Icon Composer source for the README and Alfred.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICTOOL="${ICTOOL:-$(dirname "$(xcode-select -p)")/Applications/Icon Composer.app/Contents/Executables/ictool}"
[ -x "$ICTOOL" ] || { echo "Icon Composer's ictool was not found. Set ICTOOL to its path." >&2; exit 1; }
for rendition in Default Dark; do
    case "$rendition" in Default) name=light ;; Dark) name=dark ;; esac
    "$ICTOOL" "$ROOT/assets/netlifylogo.icon" --export-image \
        --output-file "$ROOT/assets/netlifylogo-$name.png" \
        --platform macOS --rendition "$rendition" --width 1024 --height 1024 --scale 1
done
cp "$ROOT/assets/netlifylogo-dark.png" "$ROOT/workflow/icon.png"
