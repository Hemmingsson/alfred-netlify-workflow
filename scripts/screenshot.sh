#!/bin/sh
# Capture the window with the demo sites for the README: assets/screenshot.png.
# Opens the window through the workflow's External Trigger `browse`; it never types into Alfred.
set -e
cd "$(dirname "$0")/.."
DEMO="$PWD/demo/.cache"
BUNDLE=$(/usr/bin/plutil -extract bundleid raw workflow/info.plist)
WIDTH=$(/usr/bin/plutil -extract window.size.width raw workflow/sites.alfredui/ui.json)
alfred() { osascript -e "tell application id \"com.runningwithcrayons.Alfred\" to $1"; }

scripts/build.sh --debug --install >/dev/null
rm -rf "$DEMO"
swift run -c release demo build "$DEMO"
swiftc -O scripts/window_id.swift -o "$DEMO/window_id" 2>/dev/null

alfred "set configuration \"netlify_demo\" to value \"$DEMO\" in workflow \"$BUNDLE\" exportable false"
backdrop_pid=""
trap '[ -z "$backdrop_pid" ] || kill "$backdrop_pid" 2>/dev/null; alfred "remove configuration \"netlify_demo\" in workflow \"$BUNDLE\""; alfred "reload workflow \"$BUNDLE\""' EXIT
alfred "reload workflow \"$BUNDLE\""
alfred "run trigger \"browse\" in workflow \"$BUNDLE\""

id=""
for _ in $(seq 30); do
    sleep 0.5
    id=$("$DEMO/window_id" "$WIDTH")
    [ -n "$id" ] && break
done
[ -n "$id" ] || { echo "the window did not open" >&2; exit 1; }
# Keep the wallpaper in the ignored demo cache; override with SCREENSHOT_WALLPAPER.
WALLPAPER="${SCREENSHOT_WALLPAPER:-$DEMO/tahoe-dark.jpg}"
if [ -z "${SCREENSHOT_WALLPAPER:-}" ]; then
    curl --fail --location --silent --show-error \
        'https://9to5mac.com/wp-content/uploads/sites/6/2025/06/macOS_26_Dark.jpg' \
        -o "$WALLPAPER"
fi
swiftc scripts/screenshot_background.swift -o "$DEMO/backdrop"
"$DEMO/backdrop" "$id" "$WALLPAPER" "$DEMO/capture-rect" &
backdrop_pid=$!
for _ in $(seq 30); do
    [ -f "$DEMO/capture-rect" ] && break
    sleep 0.2
done
[ -f "$DEMO/capture-rect" ] || { echo "backdrop did not open" >&2; exit 1; }
rect=$(cat "$DEMO/capture-rect")
# The window takes a while to draw its pictures and live previews: capture a few times and keep the largest
# PNG (a blank or half-drawn window compresses smaller).
best=0
for n in $(seq 8); do
    sleep 1.5
    screencapture -x -R "$rect" "$DEMO/shot.png" 2>/dev/null || continue
    size=$(stat -f %z "$DEMO/shot.png")
    [ "$size" -gt "$best" ] && best=$size && cp "$DEMO/shot.png" assets/screenshot.png
done
[ "$best" -gt 300000 ] || { echo "the window did not draw (largest capture $best bytes)" >&2; exit 1; }
echo assets/screenshot.png
