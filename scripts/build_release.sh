#!/usr/bin/env bash
set -euo pipefail

# Fixed values
TEAM_ID="QUR8QTGXNB"
ORG_REVERSE_DOMAIN="ch.argio"
BUNDLE_APP="ch.argio.psso"
BUNDLE_EXT="ch.argio.psso.ssoe"
APP_NAME="Argio Platform SSO"
EXT_NAME="Argio Platform SSO Extension"
ISSUER="https://auth.argio.ch"
AUTHZ="${ISSUER}/application/o/authorize/"
TOKEN="${ISSUER}/application/o/token/"
SCOPE="openid profile email offline_access"

# Secrets from environment
: "${APPLE_ID:?Set APPLE_ID in environment}"
: "${APP_SPECIFIC_PWD:?Set APP_SPECIFIC_PWD in environment}"

set -x

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PROJ="${ROOT_DIR}/Scissors.xcodeproj"
SCHEME="Argio Platform SSO"
BUILD_DIR="${ROOT_DIR}/build"
EXPORT_DIR="${BUILD_DIR}/export"
ARCHIVE_PATH="${BUILD_DIR}/ArgioPlatformSSO.xcarchive"
PKG_PATH="${BUILD_DIR}/${APP_NAME}.pkg"
DIST_DIR="${ROOT_DIR}/dist"

check_tools() {
  for t in /usr/bin/xcodebuild /usr/bin/plutil /usr/libexec/PlistBuddy /usr/bin/codesign /usr/bin/productbuild /usr/bin/stapler /usr/bin/xcrun; do
    [ -x "$t" ] || { echo "Missing tool: $t"; exit 1; }
  done
}

ensure_notary_profile() {
  # Try to create the notary profile; ignore if it already exists
  xcrun notarytool store-credentials AC_NOTARY \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APP_SPECIFIC_PWD" 2>/dev/null || true
}

prepare() {
  mkdir -p "$BUILD_DIR" "$EXPORT_DIR" "$DIST_DIR"
}

validate_project() {
  /usr/bin/xcodebuild -list -project "$PROJ" || true

  # Ensure bundle identifiers match expectations for macOS targets
  # ssoe-macos extension
  /usr/libexec/PlistBuddy -c "Set :objects:5177E3FE8DFC0FF72721FED7:buildSettings:PRODUCT_BUNDLE_IDENTIFIER $BUNDLE_EXT" "${PROJ}/project.pbxproj" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Set :objects:A0D123313BDEB9B6592B1B9E:buildSettings:PRODUCT_BUNDLE_IDENTIFIER $BUNDLE_EXT" "${PROJ}/project.pbxproj" 2>/dev/null || true

  # Argio Platform SSO app
  /usr/libexec/PlistBuddy -c "Set :objects:1F0E2C197BEF43E6AA8C5E01:buildSettings:PRODUCT_BUNDLE_IDENTIFIER $BUNDLE_APP" "${PROJ}/project.pbxproj" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Set :objects:1F0E2C1A7BEF43E6AA8C5E01:buildSettings:PRODUCT_BUNDLE_IDENTIFIER $BUNDLE_APP" "${PROJ}/project.pbxproj" 2>/dev/null || true
}

build_archive() {
  /usr/bin/xcodebuild -project "$PROJ" -scheme "$SCHEME" -configuration Release clean || true
  /usr/bin/xcodebuild -project "$PROJ" -scheme "$SCHEME" -configuration Release -archivePath "$ARCHIVE_PATH" archive
}

export_app() {
  cat >"${BUILD_DIR}/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
</dict>
</plist>
EOF
  /usr/bin/xcodebuild -exportArchive -archivePath "$ARCHIVE_PATH" -exportOptionsPlist "${BUILD_DIR}/ExportOptions.plist" -exportPath "$EXPORT_DIR"
}

verify_codesign() {
  /usr/bin/codesign --verify --deep --strict --verbose=2 "${EXPORT_DIR}/${APP_NAME}.app"
}

build_pkg() {
  /usr/bin/productbuild --component "${EXPORT_DIR}/${APP_NAME}.app" /Applications "$PKG_PATH" --sign "Developer ID Installer: Yannick Meyer-Wildhagen (${TEAM_ID})"
}

notarize_and_staple() {
  /usr/bin/xcrun notarytool submit "$PKG_PATH" --keychain-profile AC_NOTARY --wait
  /usr/bin/xcrun stapler staple "$PKG_PATH"
}

copy_artifacts() {
  cp -f "$PKG_PATH" "$DIST_DIR/${APP_NAME}.pkg"
  cp -f "${ROOT_DIR}/deployment/psso-ARGON.mobileconfig" "$DIST_DIR/psso-ARGON.mobileconfig"
  cp -f "${ROOT_DIR}/deployment/psso-MORA.mobileconfig" "$DIST_DIR/psso-MORA.mobileconfig"
  cat >"${DIST_DIR}/README-DEPLOY.md" <<MD
# Deployment

- Host AASA at: https://auth.argio.ch/.well-known/apple-app-site-association (Content-Type: application/json)
- AASA template: deployment/apple-app-site-association.json
- Upload ${APP_NAME}.pkg and both .mobileconfig profiles to Mosyle MDM.
- Verify AASA: sudo swcutil dl -d auth.argio.ch && sudo swcutil show

MD
}

main() {
  check_tools
  ensure_notary_profile
  prepare
  validate_project
  build_archive
  export_app
  verify_codesign
  build_pkg
  notarize_and_staple
  copy_artifacts
  echo "Artifacts ready in: ${DIST_DIR}"
}

main "$@"
