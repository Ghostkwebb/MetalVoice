#!/bin/bash
APP_NAME="MetalVoice"
BUILD_DIR=".build/debug"
APP_BUNDLE="$APP_NAME.app"

# Clean
rm -rf "$APP_BUNDLE"

# Structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy Binary
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Copy Info.plist
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/"

# Copy Resources (CoreML Model, Icon, Logo)
# Note: CoreML compiles to .mlmodelc
cp -r "Resources/DeepFilterNet3_Streaming.mlmodelc" "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || echo "Model not compiled? Skipping"
cp "Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
cp "Resources/MetalVoiceLogo.png" "$APP_BUNDLE/Contents/Resources/"

# Sign with Entitlements (Crucial for Microphone Access)
codesign --force --deep --sign - --entitlements "Resources/MetalVoice.entitlements" "$APP_BUNDLE"

echo "Bundled and Signed $APP_BUNDLE"
