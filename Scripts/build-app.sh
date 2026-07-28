#!/bin/sh

set -eu

unset CDPATH
PROJECT_DIR=$(cd -- "$(dirname -- "$0")/.." && pwd)
APP_DIR="$PROJECT_DIR/dist/FreshProfile.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$PROJECT_DIR"
swift build -c release
BIN_DIR=$(swift build -c release --show-bin-path)

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_DIR/FreshProfile" "$MACOS_DIR/FreshProfile"
cp "$PROJECT_DIR/Support/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/Assets/FreshProfile.icns" "$RESOURCES_DIR/FreshProfile.icns"

echo "$APP_DIR"
