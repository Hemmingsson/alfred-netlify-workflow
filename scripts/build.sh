#!/bin/bash
# Build the Netlify Alfred workflow: one universal `netlify` binary inside the workflow folder.
#
#   scripts/build.sh             release build: universal binary, signed, notarised when configured,
#                                zipped to dist/Netlify.alfredworkflow
#   scripts/build.sh --debug     debug build for this Mac only, signed with the Apple Development identity
#                                (ad-hoc when there is none), no notarising (fast)
#   scripts/build.sh --install   also replace the workflow installed in Alfred and reload it
#   scripts/build.sh --help      show this help
#
# Settings (environment variables):
#   SIGN_IDENTITY        codesign identity; default: the first "Developer ID Application" identity in the
#                        keychain (with --debug: the first "Apple Development" one, so Keychain access
#                        survives rebuilds), else ad-hoc ("-"), which only runs on this Mac
#   NOTARY_PROFILE       notarytool keychain profile; when set, the binary is notarised (see docs/releasing.md)
#   PACKAGE_DIR          the Swift package to build; default: the repository root
#   ALFRED_WORKFLOWS_DIR where --install puts the workflow; default: Alfred's own workflows folder. When set,
#                        Alfred is not asked to reload (it is not watching that folder).
#
# See docs/releasing.md for the one-time setup and the release steps.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE_DIR="${PACKAGE_DIR:-$ROOT}"
WORKFLOW_SRC="$ROOT/workflow"
DIST="$ROOT/dist"
STAGE="$DIST/Netlify"
OUTPUT="$DIST/Netlify.alfredworkflow"
PRODUCT="netlify"
ENTITLEMENTS="$ROOT/scripts/netlify.entitlements" # used only if it exists; none are needed today

ALFRED_APP="com.runningwithcrayons.Alfred"
BUNDLE_ID="$(/usr/bin/plutil -extract bundleid raw "$WORKFLOW_SRC/info.plist")"
# Fixed folder id, so a first install gets a stable folder name.
INSTALL_ID="6F2B1C1E-5D0A-4B7E-9C51-1A9E0E6F7A00"

# --------------------------------------------------------------------------- options

DEBUG=0
INSTALL=0
for arg in "$@"; do
  case "$arg" in
    --debug) DEBUG=1 ;;
    --install) INSTALL=1 ;;
    --help | -h)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown option: $arg (try --help)" >&2
      exit 2
      ;;
  esac
done

step() { printf '\n==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }

# --------------------------------------------------------------------------- build

step "Building $PRODUCT ($([ "$DEBUG" = 1 ] && echo "debug, this Mac only" || echo "release, arm64 + x86_64"))"
if [ "$DEBUG" = 1 ]; then
  BUILD_ARGS=(--package-path "$PACKAGE_DIR" -c debug --product "$PRODUCT")
else
  BUILD_ARGS=(--package-path "$PACKAGE_DIR" -c release --arch arm64 --arch x86_64 --product "$PRODUCT")
fi
swift build "${BUILD_ARGS[@]}"
BINARY="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)/$PRODUCT"
/usr/bin/lipo -info "$BINARY"

step "Staging $STAGE"
rm -rf "$STAGE"
mkdir -p "$STAGE"
/usr/bin/ditto "$WORKFLOW_SRC" "$STAGE"
/usr/bin/ditto "$BINARY" "$STAGE/$PRODUCT"
find "$STAGE" -name .DS_Store -delete
chmod 755 "$STAGE/$PRODUCT" "$STAGE"/sites.alfredui/scripts/*

# --------------------------------------------------------------------------- sign

# The SHA-1 of the first valid codesigning identity whose name starts with $1, or nothing. A hash, because two
# certificates can share a name.
first_identity() {
  /usr/bin/security find-identity -v -p codesigning |
    awk -v kind="\"$1" 'index($0, kind) { print $2; exit }'
}

# Pick the identity: SIGN_IDENTITY, else Developer ID Application (release) or Apple Development (debug), else
# ad-hoc. A stable identity keeps the Keychain's "allow access" for the token across rebuilds.
if [ -n "${SIGN_IDENTITY:-}" ]; then
  IDENTITY="$SIGN_IDENTITY"
elif [ "$DEBUG" = 1 ]; then
  IDENTITY="$(first_identity "Apple Development:")"
else
  IDENTITY="$(first_identity "Developer ID Application:")"
fi
IDENTITY="${IDENTITY:--}"
IDENTITY_NAME="$IDENTITY"
if [ "$IDENTITY" != "-" ]; then
  IDENTITY_NAME="$(/usr/bin/security find-identity -v -p codesigning |
    awk -F'"' -v id="$IDENTITY" 'index($0, id) { print $2; exit }')"
  IDENTITY_NAME="${IDENTITY_NAME:-$IDENTITY}"
fi

# Hardened runtime is required for notarising. No entitlements are needed: see docs/releasing.md.
# Always the same identifier (the bundle id) instead of the linker's "netlify-<hash>": the Keychain's designated
# requirement for the token names it.
SIGN_ARGS=(--force --options runtime --identifier "$BUNDLE_ID")
if [ "$IDENTITY" = "-" ]; then
  if [ "$DEBUG" = 0 ]; then
    warn "no Developer ID Application identity found; signing ad-hoc."
    warn "The result runs on this Mac only. Other Macs will block it, and it cannot be notarised."
  fi
  SIGN_ARGS+=(--sign -) # a secure timestamp needs a real identity
elif [ "$DEBUG" = 1 ]; then
  SIGN_ARGS+=(--sign "$IDENTITY" --timestamp=none) # no round trip to Apple's timestamp server
else
  SIGN_ARGS+=(--sign "$IDENTITY" --timestamp)
fi
if [ -f "$ENTITLEMENTS" ]; then
  SIGN_ARGS+=(--entitlements "$ENTITLEMENTS")
fi

step "Signing with $([ "$IDENTITY" = "-" ] && echo "ad-hoc identity (-)" || echo "$IDENTITY_NAME")"
/usr/bin/codesign "${SIGN_ARGS[@]}" "$STAGE/$PRODUCT"
/usr/bin/codesign --verify --strict --verbose=2 "$STAGE/$PRODUCT"
/usr/bin/codesign -dvv "$STAGE/$PRODUCT" 2>&1 | grep -E '^(Identifier|Format|CodeDirectory|Authority|Signature|Timestamp|Runtime)'

# --------------------------------------------------------------------------- notarise

if [ "$DEBUG" = 1 ]; then
  : # never notarise a debug build
elif [ -z "${NOTARY_PROFILE:-}" ]; then
  step "Not notarising (NOTARY_PROFILE is not set)"
  echo "To notarise, create a keychain profile once and pass its name:"
  echo "  xcrun notarytool store-credentials netlify-notary --apple-id <you@example.com> --team-id <TEAMID>"
  echo "  NOTARY_PROFILE=netlify-notary scripts/build.sh"
elif [ "$IDENTITY" = "-" ] || [[ "$IDENTITY_NAME" != "Developer ID Application:"* ]]; then
  warn "NOTARY_PROFILE is set, but only Developer ID builds can be notarised; skipping."
else
  step "Notarising with profile $NOTARY_PROFILE (this takes a few minutes)"
  SUBMISSION="$DIST/$PRODUCT-notarise.zip"
  /usr/bin/ditto -c -k --keepParent "$STAGE/$PRODUCT" "$SUBMISSION"
  RESULT="$(xcrun notarytool submit "$SUBMISSION" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json)"
  rm -f "$SUBMISSION"
  echo "$RESULT"
  STATUS="$(echo "$RESULT" | /usr/bin/plutil -extract status raw - 2>/dev/null || echo unknown)"
  if [ "$STATUS" != "Accepted" ]; then
    ID="$(echo "$RESULT" | /usr/bin/plutil -extract id raw - 2>/dev/null || echo '<id>')"
    echo "Notarisation failed ($STATUS). Details:" >&2
    echo "  xcrun notarytool log $ID --keychain-profile $NOTARY_PROFILE" >&2
    exit 1
  fi

  # A bare binary cannot be stapled; Gatekeeper looks the ticket up online the first time it runs.

  step "Checking the notarised binary"
  /usr/bin/codesign --verify --strict --verbose=2 "$STAGE/$PRODUCT"
  # Accepted with "source=Notarized Developer ID" only once Apple has the ticket.
  /usr/sbin/spctl -a -vvv -t install "$STAGE/$PRODUCT"
fi

# --------------------------------------------------------------------------- package

step "Packaging $OUTPUT"
rm -f "$OUTPUT"
# Zip the folder's contents (not the folder itself); ditto keeps the executable bits.
/usr/bin/ditto -c -k --norsrc --noextattr "$STAGE" "$OUTPUT"
echo "$OUTPUT"

# --------------------------------------------------------------------------- install

# Alfred's workflows folder, honouring a synced preferences folder.
workflows_dir() {
  local synced
  synced="$(/usr/bin/defaults read com.runningwithcrayons.Alfred-Preferences syncfolder 2>/dev/null || true)"
  synced="${synced/#\~/$HOME}"
  echo "${synced:-$HOME/Library/Application Support/Alfred}/Alfred.alfredpreferences/workflows"
}

# Replace the installed copy in place (the same folder keeps Alfred's settings), or add a new one.
install_workflow() {
  local root target="" plist prefs=""
  root="${ALFRED_WORKFLOWS_DIR:-$(workflows_dir)}"
  mkdir -p "$root"
  for plist in "$root"/*/info.plist; do
    [ -f "$plist" ] || continue
    if [ "$(/usr/bin/plutil -extract bundleid raw "$plist" 2>/dev/null || true)" = "$BUNDLE_ID" ]; then
      target="$(dirname "$plist")"
      break
    fi
  done
  target="${target:-$root/user.workflow.$INSTALL_ID}"

  # Keep the user's settings (keyword, refresh minutes) across the reinstall.
  if [ -f "$target/prefs.plist" ]; then
    prefs="$(mktemp -d)/prefs.plist"
    cp -p "$target/prefs.plist" "$prefs"
  fi
  rm -rf "$target"
  /usr/bin/ditto -x -k "$OUTPUT" "$target"
  chmod 755 "$target/$PRODUCT" "$target"/sites.alfredui/scripts/*
  if [ -n "$prefs" ]; then
    mv "$prefs" "$target/prefs.plist"
  fi
  echo "installed: $target"

  if [ -z "${ALFRED_WORKFLOWS_DIR:-}" ]; then
    /usr/bin/osascript -e "tell application id \"$ALFRED_APP\" to reload workflow \"$BUNDLE_ID\"" ||
      warn "could not ask Alfred to reload the workflow; it picks up the change on its own shortly."
  fi
}

if [ "$INSTALL" = 1 ]; then
  step "Installing into Alfred"
  install_workflow
fi
