#!/bin/bash
# Build MINT.app (Release, ad-hoc signed), bundle the mediainfo CLI self-contained,
# and produce a drag-to-Applications DMG. macOS 26 requires ad-hoc signing — never
# switch to Apple Development (kernel SIGKILLs those). No notarization (no dev account).
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="MINT"
SCHEME="MINT"
BUILD="build"
DERIVED="$BUILD/DerivedData"
APP="$BUILD/$APP_NAME.app"
DMG="$BUILD/$APP_NAME.dmg"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

echo "▸ Clean"
rm -rf "$APP" "$DMG" "$BUILD/dmg"

echo "▸ Build (Release, ad-hoc)"
xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$SCHEME" -configuration Release \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual AD_HOC_CODE_SIGNING_ALLOWED=YES \
  clean build | tail -1

ditto "$DERIVED/Build/Products/Release/$APP_NAME.app" "$APP"

echo "▸ Bundle mediainfo CLI"
RES="$APP/Contents/Resources/MediaInfoCLI"
mkdir -p "$RES"
cp "$(readlink -f /opt/homebrew/bin/mediainfo)"                        "$RES/mediainfo"
cp "$(readlink -f /opt/homebrew/opt/libmediainfo/lib/libmediainfo.0.dylib)" "$RES/libmediainfo.0.dylib"
cp "$(readlink -f /opt/homebrew/opt/libzen/lib/libzen.0.dylib)"        "$RES/libzen.0.dylib"
chmod u+w "$RES"/*

# Rewire load paths to be self-contained (@loader_path = the MediaInfoCLI dir).
install_name_tool -id @loader_path/libzen.0.dylib        "$RES/libzen.0.dylib"
install_name_tool -id @loader_path/libmediainfo.0.dylib  "$RES/libmediainfo.0.dylib"
install_name_tool -change /opt/homebrew/opt/libzen/lib/libzen.0.dylib @loader_path/libzen.0.dylib "$RES/libmediainfo.0.dylib"
install_name_tool -change /opt/homebrew/opt/libmediainfo/lib/libmediainfo.0.dylib @loader_path/libmediainfo.0.dylib "$RES/mediainfo"
install_name_tool -change /opt/homebrew/opt/libzen/lib/libzen.0.dylib @loader_path/libzen.0.dylib "$RES/mediainfo"

echo "▸ Sign (inside-out, ad-hoc)"
codesign --force -s - "$RES/libzen.0.dylib"
codesign --force -s - "$RES/libmediainfo.0.dylib"
codesign --force -s - "$RES/mediainfo"
codesign --force -s - "$APP"

echo "▸ Verify self-contained mediainfo"
"$RES/mediainfo" --version | head -1
otool -L "$RES/mediainfo" | grep -q homebrew && { echo "✗ still links homebrew"; exit 1; } || echo "  ✓ no homebrew links"

echo "▸ DMG"
STAGE="$BUILD/dmg"
rm -rf "$STAGE"; mkdir -p "$STAGE"
ditto "$APP" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

# Keep Finder's "Open With" menu clean. Spotlight auto-registers any .app it
# finds, so build-tree copies pile up as stale "MINT" entries. Mark the build
# tree as never-index, and unregister any build-tree MINT.app LS already knows.
touch "$BUILD/.metadata_never_index"
while IFS= read -r dev_app; do
  "$LSREGISTER" -u "$dev_app" 2>/dev/null || true
done < <(find "$BUILD" -maxdepth 6 -name "MINT.app" -type d 2>/dev/null)

echo "✓ Built $APP"
echo "✓ Packaged $DMG ($(du -h "$DMG" | cut -f1))"

# Sign the DMG with EdDSA so Sparkle clients can verify the update.
# sign_update finds the private key in the login Keychain automatically.
VERSION=$(grep 'MARKETING_VERSION' "$APP_NAME.xcodeproj/project.pbxproj" | head -1 | sed 's/.*= //;s/;//;s/ //')
BUILD_NUMBER=$(grep 'CURRENT_PROJECT_VERSION' "$APP_NAME.xcodeproj/project.pbxproj" | head -1 | sed 's/.*= //;s/;//;s/ //')
SIGN_UPDATE="$DERIVED/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"
if [ -x "$SIGN_UPDATE" ]; then
  echo "▸ Sign DMG for Sparkle"
  EDDSA_SIG=$("$SIGN_UPDATE" "$DMG" 2>/dev/null | sed 's/.*sparkle:edSignature="\([^"]*\)".*/\1/')
  DMG_SIZE=$(stat -f%z "$DMG")
  echo ""
  echo "  *** appcast.xml <enclosure> values for v$VERSION:"
  echo "      sparkle:version=\"$BUILD_NUMBER\""
  echo "      sparkle:shortVersionString=\"$VERSION\""
  echo "      sparkle:edSignature=\"$EDDSA_SIG\""
  echo "      length=\"$DMG_SIZE\""
else
  echo "  Note: sign_update not found — run the build once to resolve Sparkle, then re-run."
fi
