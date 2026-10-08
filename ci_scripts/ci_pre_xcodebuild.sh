#!/bin/sh
set -eu

BUILD_NUMBER="${CI_BUILD_NUMBER:-}"
SCRIPT_DIR="$(CDPATH= cd "$(dirname "$0")" && pwd)"

if [ -z "$BUILD_NUMBER" ]; then
  echo "CI_BUILD_NUMBER is not set; keeping the committed CFBundleVersion."
  exit 0
fi

PLIST_PATH=""
for CANDIDATE_ROOT in \
  "${CI_PRIMARY_REPOSITORY_PATH:-}" \
  "$(pwd)" \
  "$SCRIPT_DIR/.." \
  "$SCRIPT_DIR"; do
  if [ -n "$CANDIDATE_ROOT" ] && [ -f "$CANDIDATE_ROOT/NativeDemoApp/Info.plist" ]; then
    PLIST_PATH="$CANDIDATE_ROOT/NativeDemoApp/Info.plist"
    break
  fi
done

if [ -z "$PLIST_PATH" ]; then
  SEARCH_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$SCRIPT_DIR/..}"
  PLIST_PATH="$(find "$SEARCH_ROOT" -path '*/NativeDemoApp/Info.plist' -type f -print -quit 2>/dev/null || true)"
fi

if [ -z "$PLIST_PATH" ]; then
  echo "Warning: NativeDemoApp/Info.plist was not found; keeping the committed build number." >&2
  echo "CI_PRIMARY_REPOSITORY_PATH=${CI_PRIMARY_REPOSITORY_PATH:-<unset>}" >&2
  echo "Script directory=$SCRIPT_DIR" >&2
  echo "Working directory=$(pwd)" >&2
  exit 0
fi

echo "Using Info.plist at $PLIST_PATH"

if [ -x /usr/libexec/PlistBuddy ]; then
  if ! /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$PLIST_PATH"; then
    echo "PlistBuddy failed; trying plutil" >&2
    /usr/bin/plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$PLIST_PATH"
  fi
else
  /usr/bin/plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$PLIST_PATH"
fi

WRITTEN_BUILD_NUMBER="$(/usr/bin/plutil -extract CFBundleVersion raw -o - "$PLIST_PATH")"
if [ "$WRITTEN_BUILD_NUMBER" != "$BUILD_NUMBER" ]; then
  echo "CFBundleVersion readback mismatch: expected $BUILD_NUMBER, got $WRITTEN_BUILD_NUMBER" >&2
  exit 1
fi

echo "Set CFBundleVersion to $BUILD_NUMBER"
