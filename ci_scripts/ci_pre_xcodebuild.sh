#!/bin/sh
set -eu

BUILD_NUMBER="${CI_BUILD_NUMBER:-}"
SCRIPT_DIR="$(CDPATH= cd "$(dirname "$0")" && pwd)"

if [ -z "$BUILD_NUMBER" ]; then
  echo "CI_BUILD_NUMBER is not set; keeping the committed CFBundleVersion."
  exit 0
fi

if [ -n "${CI_PRIMARY_REPOSITORY_PATH:-}" ]; then
  REPOSITORY_PATH="$CI_PRIMARY_REPOSITORY_PATH"
elif [ -f "$(pwd)/NativeDemoApp/Info.plist" ]; then
  REPOSITORY_PATH="$(pwd)"
elif [ -f "$SCRIPT_DIR/../NativeDemoApp/Info.plist" ]; then
  REPOSITORY_PATH="$(CDPATH= cd "$SCRIPT_DIR/.." && pwd)"
elif [ -f "$SCRIPT_DIR/NativeDemoApp/Info.plist" ]; then
  REPOSITORY_PATH="$SCRIPT_DIR"
else
  echo "Unable to locate repository root containing NativeDemoApp/Info.plist" >&2
  echo "CI_PRIMARY_REPOSITORY_PATH=${CI_PRIMARY_REPOSITORY_PATH:-<unset>}" >&2
  echo "Script directory=$SCRIPT_DIR" >&2
  echo "Working directory=$(pwd)" >&2
  exit 1
fi

PLIST_PATH="$REPOSITORY_PATH/NativeDemoApp/Info.plist"
echo "Using Info.plist at $PLIST_PATH"

if [ ! -f "$PLIST_PATH" ]; then
  echo "Info.plist disappeared before update: $PLIST_PATH" >&2
  exit 1
fi

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
