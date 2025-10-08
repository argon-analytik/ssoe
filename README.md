# Argio Platform SSO (Apple Extensible/Platform SSO)

Universal (macOS + iOS) Authentication Services extension that implements Apple’s
Extensible SSO / Platform SSO for the Argio platform (OIDC). The repository
contains a macOS host app, iOS and macOS SSO extensions, and shared code for a
Redirect‑based OIDC flow with PKCE, Keychain token storage, and MDM‑driven config.

This README explains the full layout, configuration, build/sign/notarize process,
generated artifacts (.pkg and .mobileconfig), and deployment with Mosyle.

---

## Overview

- Implements an Authentication Services extension (idp‑extension) that:
  - Detects requests to `https://auth.argio.ch` and performs OIDC Authorization Code + PKCE
  - Exchanges code for tokens (`/application/o/token/`) and stores them in Keychain
  - Adds `Authorization: Bearer <access_token>` headers on success
  - Refreshes tokens when expired (if `refresh_token` available)
- A macOS host app container is included for packaging and distribution as a signed, notarized `.pkg`.
- Two pre‑filled Mosyle `.mobileconfig` profiles complete the setup for Redirect SSO.

---

## Fixed Values and Identifiers

- Team/Org
  - TEAM_ID: `QUR8QTGXNB`
  - ORG_REVERSE_DOMAIN: `ch.argio`
- Bundle IDs
  - Container (macOS host app): `ch.argio.psso`
  - Extension (macOS/iOS): `ch.argio.psso.ssoe`
- Names
  - APP_NAME: `Argio Platform SSO`
  - EXT_NAME: `Argio Platform SSO Extension`
- OIDC Defaults
  - ISSUER: `https://auth.argio.ch`
  - AUTHZ: `${ISSUER}/application/o/authorize/`
  - TOKEN: `${ISSUER}/application/o/token/`
  - SCOPE: `openid profile email offline_access`

Secrets are read from the environment for notarization:

- APPLE_ID (Apple ID for notarytool)
- APP_SPECIFIC_PWD (app‑specific password for notarytool)

---

## Repository Structure

```
.
├── Scissors.xcodeproj/              # Xcode project (iOS app, iOS+macOS extensions, macOS host app)
│   └── xcshareddata/xcschemes/
│       └── Argio Platform SSO.xcscheme
├── Scissors-ios/                    # iOS sample container app (for local testing)
├── ssoe-ios/                        # iOS SSO extension (idp-extension)
├── ssoe-macos/                      # macOS SSO extension (idp-extension)
├── psso-macos/                      # macOS host app (no UI)
├── Shared/                          # Shared code across extensions
│   ├── AuthenticationViewController+Shared.swift
│   ├── AuthorizationProvider.swift
│   ├── Cookies.swift
│   ├── OIDC.swift                   # PKCE + token exchange/refresh
│   ├── OIDCConfig.swift             # Reads MDM AdditionalSettings
│   └── TokenStore.swift             # Keychain storage
├── entitlements/
│   ├── psso-app.entitlements        # App: Associated Domains (authsrv)
│   └── psso-ext.entitlements        # Extension: empty (capability applied)
├── deployment/
│   ├── apple-app-site-association.json  # AASA template
│   ├── psso-ARGON.mobileconfig          # Mosyle profile template
│   └── psso-MORA.mobileconfig           # Mosyle profile template
├── scripts/
│   └── build_release.sh             # One‑shot build/sign/notarize/package script
└── dist/                             # Output artifacts (created by the script)
```

---

## Targets and Bundle IDs

- macOS Host App
  - Target: `Argio Platform SSO`
  - Bundle ID: `ch.argio.psso`
  - Deployment target: macOS 13+
  - Entitlements: `entitlements/psso-app.entitlements` (Associated Domains)
- macOS Extension
  - Target: `ssoe-macos`
  - Bundle ID: `ch.argio.psso.ssoe`
  - Deployment target: macOS 13+
  - NSExtensionPoint: `com.apple.AppSSO.idp-extension`
- iOS Extension (optional for testing Safari/App SSO)
  - Target: `ssoe-ios`
  - Bundle ID: `ch.argio.psso.ssoe`
  - Deployment target: iOS 17 (as configured)
- iOS Sample App (optional)
  - Target: `Scissors-ios`

Signing (Release) is set to Manual for macOS targets with:

- DEVELOPMENT_TEAM = `QUR8QTGXNB`
- CODE_SIGN_IDENTITY (App/Ext): `Developer ID Application: Yannick Meyer‑Wildhagen (QUR8QTGXNB)`

Installer packaging uses:

- `Developer ID Installer: Yannick Meyer‑Wildhagen (QUR8QTGXNB)`

---

## Entitlements and Capabilities

- App (`entitlements/psso-app.entitlements`)
  - `com.apple.developer.associated-domains = ["authsrv:auth.argio.ch?mode=developer"]`
    - Required for Associated Domains / Apple App Site Association (AASA)
- Extension (`entitlements/psso-ext.entitlements`)
  - Kept empty; network entitlement managed via Xcode Capabilities for the extension

---

## Extension Info.plist

Both iOS and macOS extensions declare `NSExtension` with:

- `NSExtensionPointIdentifier = com.apple.AppSSO.idp-extension`
- `NSExtensionPrincipalClass = $(PRODUCT_MODULE_NAME).AuthenticationViewController`
- Attributes include:
  - `ASAuthorizationProviderExtensionIssuer = https://auth.argio.ch`
  - `ASAuthorizationProviderExtensionClientID = ch.argio.sso`
  - `ASAuthorizationProviderExtensionSupportsPlatformSSO = true`

---

## OIDC Flow and Configuration

The extension reads configuration from the Extensible SSO payload’s
`AdditionalSettings` dictionary (MDM). Supported keys:

- `issuer` (URL, e.g. `https://auth.argio.ch`)
- `authorize` (URL, e.g. `${ISSUER}/application/o/authorize/`)
- `token` (URL, e.g. `${ISSUER}/application/o/token/`)
- `scopes` (string, default `openid profile email offline_access`)
- `client_id`
- `client_secret` (optional)
- `redirect_uri` (optional; default `ch.argio.psso://oauth/callback`)

Behavior:

- If the request URL matches the issuer host, the extension starts an Authorization Code + PKCE flow to `authorize` and exchanges code for tokens at `token`.
- Tokens are stored in Keychain (`psso` service). Refresh is attempted when access token is expired.
- On success, the extension sets `Authorization: Bearer <access_token>` on the response.

Relevant source files: `Shared/OIDCConfig.swift`, `Shared/OIDC.swift`, `Shared/TokenStore.swift`, `Shared/AuthenticationViewController+Shared.swift`.

---

## Apple App Site Association (AASA)

- Template: `deployment/apple-app-site-association.json`
- Must be hosted at: `https://auth.argio.ch/.well-known/apple-app-site-association`
- Content‑Type: `application/json`
- Validation:
  - `sudo swcutil dl -d auth.argio.ch`
  - `sudo swcutil show`

---

## Mosyle MDM Profiles (Redirect SSO)

Two templates are provided, identical except for Payload IDs/UUIDs:

- `deployment/psso-ARGON.mobileconfig`
- `deployment/psso-MORA.mobileconfig`

Common keys:

- `PayloadType = com.apple.extensiblesso`
- `TeamIdentifier = QUR8QTGXNB`
- `Type = Redirect`
- `ExtensionIdentifier = ch.argio.psso.ssoe`
- `URLs = [ "https://auth.argio.ch/" ]`
- `AdditionalSettings` dictionary contains:
  - `issuer`, `authorize`, `token`, `scopes`, `client_id`, `client_secret`, `redirect_uri`

Before uploading, set `client_id` and `client_secret` to your OIDC client values.

---

## Build, Sign, Notarize, Package (macOS)

One‑shot script:

```bash
export APPLE_ID="yannick@meyer-wildhagen.com"
export APP_SPECIFIC_PWD="<app-specific-password>"

scripts/build_release.sh
```

What the script does:

- Verifies required tools: `xcodebuild`, `plutil`, `PlistBuddy`, `codesign`, `productbuild`, `stapler`, `xcrun`
- Stores notary credentials idempotently:
  - `xcrun notarytool store-credentials AC_NOTARY --apple-id "$APPLE_ID" --team-id "QUR8QTGXNB" --password "$APP_SPECIFIC_PWD"`
- Archives the `Argio Platform SSO` scheme (Release)
- Exports the `.app` with Developer ID signing
- Verifies codesign of the exported `.app`
- Builds a signed Installer `.pkg` (Developer ID Installer)
- Submits for notarization and staples the ticket
- Copies artifacts into `dist/`

Manual reference (equivalent commands):

```bash
xcodebuild -project Scissors.xcodeproj -configuration Release -scheme "Argio Platform SSO" clean build
xcodebuild -project Scissors.xcodeproj -scheme "Argio Platform SSO" -configuration Release -archivePath build/ArgioPlatformSSO.xcarchive archive

cat > ExportOptions.plist <<EOF
{
  "method": "developer-id",
  "signingStyle": "manual",
  "teamID": "QUR8QTGXNB"
}
EOF

xcodebuild -exportArchive -archivePath build/ArgioPlatformSSO.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath build/export

codesign --verify --deep --strict --verbose=2 "build/export/Argio Platform SSO.app"

productbuild --component "build/export/Argio Platform SSO.app" /Applications "build/Argio Platform SSO.pkg" \
  --sign "Developer ID Installer: Yannick Meyer-Wildhagen (QUR8QTGXNB)"

xcrun notarytool submit "build/Argio Platform SSO.pkg" --keychain-profile AC_NOTARY --wait
xcrun stapler staple "build/Argio Platform SSO.pkg"
```

---

## Output Artifacts

After running the build script, artifacts are placed in `dist/`:

- `dist/Argio Platform SSO.pkg`
- `dist/psso-ARGON.mobileconfig`
- `dist/psso-MORA.mobileconfig`
- `dist/README-DEPLOY.md`

---

## Development and Testing

- Open `Scissors.xcodeproj` in Xcode.
- For macOS packaging, use scheme: `Argio Platform SSO`.
- For iOS Safari/App SSO testing, use scheme: `ssoe-ios` and install on a device.
- Logging: the extension uses lightweight `print` logging; integrate `os_log` as needed.

---

## Troubleshooting

- Signing errors
  - Ensure Developer ID Application/Installer certs are present in the Keychain and match `QUR8QTGXNB`.
- Notarization failures
  - Recreate notary credentials: `xcrun notarytool store-credentials AC_NOTARY ...`
  - Check Apple system status and review notarytool output for details.
- No SSO trigger
  - Verify MDM profile is installed and `URLs` includes `https://auth.argio.ch/`.
  - Confirm AASA is published and valid with `swcutil`.
- `invalid_grant` or token exchange errors
  - Check `client_id`, `client_secret`, redirect URI, and allowed scopes in your IdP.

---

## Security Notes

- Tokens are stored in the Keychain (`kSecClassGenericPassword`, service `psso`).
- PKCE challenge is computed with CryptoKit when available.
- The extension must be distributed signed + notarized to load on managed devices.

---

## License and Contributions

MIT. Contributions welcome — please keep changes focused and ensure Release
archive builds are clean before submitting PRs.
