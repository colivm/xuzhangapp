#!/bin/sh
set -eu

BUILD_NUMBER="${CI_BUILD_NUMBER:-}"
PLIST_PATH="${CI_PRIMARY_REPOSITORY_PATH:-$(pwd)}/NativeDemoApp/Info.plist"

if [ -z "$BUILD_NUMBER" ]; then
  echo "CI_BUILD_NUMBER is not set; keeping the committed CFBundleVersion."
  exit 0
fi

if [ ! -f "$PLIST_PATH" ]; then
  echo "Info.plist not found at $PLIST_PATH"
  exit 1
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$PLIST_PATH"
echo "Set CFBundleVersion to $BUILD_NUMBER"
