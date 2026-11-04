#!/bin/bash
# Build build/Plinth.app (universal). Needs macOS 14+ and Xcode 16.3+.
#
# Signed ad hoc by default, which is fine on your own Mac. To sign for
# distribution, set PLINTH_SIGN_IDENTITY to a Developer ID Application
# certificate in your keychain, e.g. "Developer ID Application: Name (TEAMID)";
# the app then gets the hardened runtime and secure timestamp that
# notarization requires, and keeps its update feed (an ad hoc build doesn't
# update itself). The Shortcuts action needs a build signed with a team ID
# (macOS won't run it ad hoc), and so, most likely, does the desktop widget's
# Knock button. PLINTH_VERSION and PLINTH_BUILD override the version (e.g.
# 1.2.0) and build number in Info.plist.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --arch arm64 --arch x86_64
BIN=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Plinth

APP=build/Plinth.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Plinth"
cp -R App/Resources/* "$APP/Contents/Resources/"
cp App/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Frameworks"
# ditto keeps the framework's relative symlinks.
ditto "$(dirname "$BIN")/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"

# The desktop widget, an app extension with its own copy of the fish.
WIDGET="$APP/Contents/PlugIns/PlinthWidget.appex"
mkdir -p "$WIDGET/Contents/MacOS" "$WIDGET/Contents/Resources"
cp "$(dirname "$BIN")/PlinthWidget" "$WIDGET/Contents/MacOS/PlinthWidget"
cp App/Widget/Info.plist "$WIDGET/Contents/Info.plist"
cp App/Resources/Skins/wooden-fish/idle.png "$WIDGET/Contents/Resources/fish.png"

# Shortcuts finds the Knock action, and the widget its Knock button, through
# App Intents metadata. Xcode extracts it when it builds an app; SwiftPM
# doesn't, so extract it here from the constant values the compiler wrote.
SCRATCH=$(mktemp -d)
intents_metadata() { # module bundle
  ls "$PWD/Sources/$1"/*.swift > "$SCRATCH/$1.sources"
  # The target's folder is $1.build, or $1-p.build in newer SwiftPM.
  find "$PWD/.build" -name '*.swiftconstvalues' -path '*/arm64/*' \
    \( -path "*/Release/$1.build/*" -o -path "*/Release/$1-p.build/*" \) > "$SCRATCH/$1.constvalues"
  xcrun appintentsmetadataprocessor --quiet-warnings \
    --output "$2/Contents/Resources" --binary-file "$2/Contents/MacOS/$1" \
    --toolchain-dir "$(dirname "$(xcrun -f swiftc)")/../.." \
    --sdk-root "$(xcrun --show-sdk-path --sdk macosx)" \
    --xcode-version "$(xcodebuild -version | awk '/Build version/ { print $3 }')" \
    --module-name "$1" --platform-family macOS --deployment-target 14.0 \
    --target-triple arm64-apple-macos14.0 \
    --source-file-list "$SCRATCH/$1.sources" --swift-const-vals-list "$SCRATCH/$1.constvalues" >/dev/null 2>&1
  test -f "$2/Contents/Resources/Metadata.appintents/extract.actionsdata" ||
    { echo "Couldn't extract the App Intents metadata for $1; it needs Xcode 16.3 or later" >&2; exit 1; }
}
intents_metadata Plinth "$APP"
intents_metadata PlinthWidget "$WIDGET"
if [ -n "${PLINTH_VERSION:-}" ]; then
  plutil -replace CFBundleShortVersionString -string "$PLINTH_VERSION" "$APP/Contents/Info.plist"
fi
if [ -n "${PLINTH_BUILD:-}" ]; then
  plutil -replace CFBundleVersion -string "$PLINTH_BUILD" "$APP/Contents/Info.plist"
fi
# An extension carries its app's version.
for key in CFBundleShortVersionString CFBundleVersion; do
  plutil -replace $key -string "$(plutil -extract $key raw "$APP/Contents/Info.plist")" "$WIDGET/Contents/Info.plist"
done

ICONSET=$(mktemp -d)/AppIcon.iconset
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s App/AppIcon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) App/AppIcon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

# Sign from the inside out, never with --deep.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
IDENTITY="${PLINTH_SIGN_IDENTITY:-}"
if [ -n "$IDENTITY" ]; then
  SIGN=(codesign --force --options runtime --timestamp --sign "$IDENTITY")
  "${SIGN[@]}" "$SPARKLE/Versions/B/XPCServices/Installer.xpc"
  "${SIGN[@]}" --preserve-metadata=entitlements "$SPARKLE/Versions/B/XPCServices/Downloader.xpc"
  "${SIGN[@]}" "$SPARKLE/Versions/B/Autoupdate"
  "${SIGN[@]}" "$SPARKLE/Versions/B/Updater.app"
  "${SIGN[@]}" "$SPARKLE"
  "${SIGN[@]}" --entitlements App/Widget/PlinthWidget.entitlements "$WIDGET"
  "${SIGN[@]}" "$APP"
  SIGNER="$IDENTITY"
else
  # Updates come signed with our Developer ID, so a build of your own gets
  # no feed and never offers to replace itself with ours. Ad hoc code also
  # can't take the hardened runtime: library validation would refuse
  # Sparkle, which has no team ID either.
  plutil -remove SUFeedURL "$APP/Contents/Info.plist"
  codesign --force --sign - "$SPARKLE"
  codesign --force --sign - --entitlements App/Widget/PlinthWidget.entitlements "$WIDGET"
  codesign --force --sign - "$APP"
  SIGNER="ad hoc"
fi
codesign --verify --deep --strict "$APP"
VERSION=$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")
echo "Built $APP $VERSION, signed $SIGNER"
