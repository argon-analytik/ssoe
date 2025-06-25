# Argio SSOE (Extensible / Platform Single Sign‑On Extension)

> **Repo rename planned:**  
> `argon-analytik/sso` → **`argon-analytik/ssoe`**  
> (SSOE = “Single Sign‑On Extension”, besser such‑ & sprechbar).

A universal (macOS + iOS) Authentication‑Extensions target that connects Apple’s
**Extensible SSO** / **Platform SSO** frameworks with your **Authentik** IdP.  
Zusammen mit dem [`psso-server-go`](https://github.com/argon-analytik/psso-server-go)
holt sich macOS beim Boot **Benutzername, Passwort, Gruppen & Secure‑Enclave‑Key**
direkt aus der Cloud.

---

## 1 · Highlights

* **macOS Login‑Fenster‑Integration** (Platform SSO)  
  – Cloud‑Passwort anstelle lokaler Accounts  
* **Safari / App SSO** auf iOS & macOS (Extensible SSO – Credential Type)  
* **Just‑in‑Time‑Account‑Creation** + Gruppen‑Mapping (“argon_admins”)  
* **Touch ID / Face ID Unlock** ab erstem Login  
* Kein AzureAD / Google‑Workspace‑Abo nötig → Authentik + Docker Stack genügt

---

## 2 · Projekt‑Struktur

```

.
├── Scissors.xcodeproj/           # Xcode project (iOS app + 2 extensions)
│   └── \*.xcscheme                # ssoe-ios / ssoe-macos (shared)
├── ssoe-ios/                     # iOS extension files
│   └── Info.plist
├── ssoe-macos/                   # macOS extension files
│   └── Info.plist
├── Shared/                       # Cookie & Helper code for both platforms
├── entitlements/
│   ├── ssoe-ios.entitlements
│   └── ssoe-macos.entitlements
└── deployment/
└── argio\_PSSO.mobileconfig   # ready‑to‑import Mosyle profile

````

---

## 3 · Prerequisites

| Tool / Account | Purpose |
|----------------|---------|
| **Xcode 15+** | Universal build & notarisation |
| **Apple Developer Team ID** | `QUR8QTGXNB` |
| **Authentik IdP** | OIDC Password‑Grant client `psso-server` |
| **PSSO Server** | Must run & expose `/v1/device/register`, `/token`, JWKS |
| **Mosyle MDM** | Distributes PKG + mobileconfig |

---

## 4 · Quick Start (macOS extension)

```bash
git clone https://github.com/argon-analytik/sso.git
cd sso
open Scissors.xcodeproj       # opens Xcode
````

1. **Scheme → `ssoe-macos`**
2. *Signing & Capabilities* → Team **QUR8QTGXNB**
3. **Product ▸ Archive**
4. Organizer ▸ Distribute ▸ **Developer ID** ▸ Upload ▸ Export PKG

> Output: `ArgioSSO.pkg` – notarisiert & stapler‑‑ready.

---

## 5 · Deploy with Mosyle

1. **Apps ▸ Add Custom App** → Upload `ArgioSSO.pkg`
2. **Profiles ▸ Add Profile (type: Custom)** → Upload `deployment/argio_PSSO.mobileconfig`

   * `ExtensionIdentifier` = `ch.argio.sso.extension-macos`
   * `TeamIdentifier` = `QUR8QTGXNB`
3. Assign to test Mac, reboot, log in with Authentik user.

---

## 6 · iOS Extension (optional)

* Switch scheme to **`ssoe-ios`**
* Connect device ➜ *Product ▸ Run* (Debug install)
* Safari → `https://auth.argio.ch` → SSO prompt appears.

---

## 7 · Configuration Keys (mobileconfig)

| Key                                 | Argio Default           | Description                       |
| ----------------------------------- | ----------------------- | --------------------------------- |
| `Issuer`                            | `https://auth.argio.ch` | Must equal `PSSO_ISSUER`          |
| `Audience`                          | `macos`                 | Mirrors `PSSO_AUDIENCE`           |
| `ClientID`                          | `ch.argio.sso`          | OIDC client used by the extension |
| `PlatformSSO › UseSharedDeviceKeys` | `true`                  | Enables Touch ID unlock tokens    |
| `EnableCreateUserAtLogin`           | `true`                  | JIT local account provisioning    |

---

## 8 · Troubleshooting

| Symptom                            | Cause                       | Fix                                                |
| ---------------------------------- | --------------------------- | -------------------------------------------------- |
| macOS falls back to local login    | Issuer / JWKS not reachable | `curl https://psso.argio.ch/.well-known/jwks.json` |
| “invalid\_grant” in PSSO log       | wrong Authentik secret      | Update `.env.psso` + restart container             |
| Extension demand “App not allowed” | Team ID mismatch            | Check `TeamIdentifier` in profile                  |

---

## 9 · Roadmap

* **Passkey‑only Flow** (macOS 15)
* **SCIM Sync** Authentik → Apple Business Manager
* **iPadOS shared device** support

---

## 10 · License & Contributions

*Swift source is MIT‑licensed (same as upstream Twocanoes sample).*

Pull‑requests welcome – please run `swiftformat` and ensure the archive build succeeds without warnings before submitting.

Happy single‑sign‑on! 🚀
