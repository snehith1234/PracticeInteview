#!/usr/bin/env bash
# Builds a distributable InterviewPracticeListener.app bundle from the SwiftPM
# release build, embedding Support/Info.plist so macOS shows the microphone /
# speech-recognition permission prompts with the correct usage strings.
#
# Output: macos/dist/InterviewPracticeListener.app
#
# Note: for microphone + speech permissions to be granted reliably, the app
# should be code-signed (see README "App signing"). An unsigned/ad-hoc build
# works for local development on your own machine.
set -euo pipefail

MACOS_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="InterviewPracticeListener"
DIST="$MACOS_DIR/dist"
APP="$DIST/$APP_NAME.app"

echo "▶ Building release binary …"
cd "$MACOS_DIR"
swift build -c release

BIN="$(swift build -c release --show-bin-path)/$APP_NAME"

echo "▶ Assembling $APP …"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$MACOS_DIR/Support/Info.plist" "$APP/Contents/Info.plist"

# Ensure CFBundle keys exist for a runnable bundle.
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $APP_NAME" "$APP/Contents/Info.plist" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $APP_NAME" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.interviewpractice.listener" "$APP/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleName string $APP_NAME" "$APP/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$APP/Contents/Info.plist" 2>/dev/null || true

# Ad-hoc sign WITH entitlements so the bundle can open the microphone and
# request TCC permissions locally. The audio-input entitlement is required or
# CoreAudio refuses to start the input node (avfaudio error 1937010544).
echo "▶ Ad-hoc signing with entitlements …"
ENTITLEMENTS="$MACOS_DIR/Support/InterviewPracticeListener.entitlements"
# NOTE: no --options runtime here. Hardened runtime + ad-hoc signing prevents
# TCC from persisting the microphone grant, so CoreAudio denies kAUStartIO.
# Ad-hoc signing WITHOUT hardened runtime is the reliable combo for a locally
# run dev build. (Enable hardened runtime only with a real Developer ID cert.)
codesign --force --deep \
  --entitlements "$ENTITLEMENTS" \
  --sign - "$APP" || echo "⚠ codesign failed (dev bundle still runnable)."

echo "✓ Built: $APP"
echo "  Run with: open \"$APP\""
