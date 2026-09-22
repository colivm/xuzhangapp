#!/bin/sh
set -eu

BUILD_NUMBER="${CI_BUILD_NUMBER:-}"
SCRIPT_DIR="$(CDPATH= cd "$(dirname "$0")" && pwd)"
REPOSITORY_PATH="${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd "$SCRIPT_DIR/.." && pwd)}"
PLIST_PATH="$REPOSITORY_PATH/NativeDemoApp/Info.plist"

if [ -z "$BUILD_NUMBER" ]; then
  echo "CI_BUILD_NUMBER is not set; keeping the committed CFBundleVersion."
  exit 0
fi

if [ ! -f "$PLIST_PATH" ]; then
  echo "Info.plist not found at $PLIST_PATH" >&2
  echo "CI_PRIMARY_REPOSITORY_PATH=${CI_PRIMARY_REPOSITORY_PATH:-<unset>}" >&2
  echo "Script directory=$SCRIPT_DIR" >&2
  exit 1
fi

if ! /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$PLIST_PATH"; then
  echo "Failed to set CFBundleVersion=$BUILD_NUMBER in $PLIST_PATH" >&2
  exit 1
fi

WRITTEN_BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST_PATH")"
if [ "$WRITTEN_BUILD_NUMBER" != "$BUILD_NUMBER" ]; then
  echo "CFBundleVersion readback mismatch: expected $BUILD_NUMBER, got $WRITTEN_BUILD_NUMBER" >&2
  exit 1
fi

echo "Set CFBundleVersion to $BUILD_NUMBER"
