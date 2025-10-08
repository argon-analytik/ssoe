Argio Platform SSO – Deployment

- Build and sign a notarized pkg and two .mobileconfig profiles.
- Prerequisites: Developer ID Application and Installer certificates, Xcode 15+, notary access.

Steps

- Export env vars: `export APPLE_ID="yannick@meyer-wildhagen.com" APP_SPECIFIC_PWD="ruhw-hptc-ulgd-ldfp"`
- Run: `scripts/build_release.sh`
- Artifacts appear in `dist/`:
  - `dist/Argio Platform SSO.pkg`
  - `dist/psso-ARGON.mobileconfig`
  - `dist/psso-MORA.mobileconfig`
  - `dist/README-DEPLOY.md`

AASA

- Publish `deployment/apple-app-site-association.json` at `https://auth.argio.ch/.well-known/apple-app-site-association` with `Content-Type: application/json`.
- Verify: `sudo swcutil dl -d auth.argio.ch` and `sudo swcutil show`.

MDM

- Upload the `.pkg` to Mosyle and add one of the `.mobileconfig` profiles.
- Fill `client_id` and `client_secret` in the `.mobileconfig` before upload.

Notes

- Bundle IDs: app `ch.argio.psso`, extension `ch.argio.psso.ssoe`.
- Team ID: `QUR8QTGXNB`. Signing is set to Manual for Release.
- macOS deployment target: 13.0.
