#!/bin/bash
set -e

APP_NAME="AntigravityBar"
DISPLAY_NAME="Antigravity Bar"
BUILD_DIR=".build/release"
APP_DIR="$DISPLAY_NAME.app"

echo "🔨 Building release..."
swift build -c release 2>&1

echo "📦 Creating .app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "Sources/AntigravityBar/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

# Copy icon
if [ -f "Sources/AntigravityBar/Resources/AppIcon.icns" ]; then
    cp "Sources/AntigravityBar/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# Sign ad-hoc (needed for SMAppService)
codesign --force --sign - "$APP_DIR"

echo "✅ Built: $APP_DIR"
echo ""
echo "To install:"
echo "  cp -r \"$APP_DIR\" /Applications/"
echo ""
echo "To run:"
echo "  open \"$APP_DIR\""
