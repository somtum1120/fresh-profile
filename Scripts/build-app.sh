#!/bin/sh

set -eu

unset CDPATH
PROJECT_DIR=$(cd -- "$(dirname -- "$0")/.." && pwd)
APP_DIR="$PROJECT_DIR/dist/FreshProfile.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

cd "$PROJECT_DIR"
swift build -c release
BIN_DIR=$(swift build -c release --show-bin-path)

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
cp "$BIN_DIR/FreshProfile" "$MACOS_DIR/FreshProfile"
cp "$PROJECT_DIR/Support/Info.plist" "$CONTENTS_DIR/Info.plist"

echo "$APP_DIR"
