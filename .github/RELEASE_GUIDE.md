# Snapgrove Release Management & Credentials Guide

This guide outlines how to configure GitHub Secrets, sign Android APKs, verify release signatures, and run the automated release workflow.

---

## 1. Credentials & Secrets Configuration

To enable automated release signing and cryptographic integrity verification in GitHub Actions, configure the following repository secrets under **Settings > Secrets and variables > Actions**:

| Secret Name | Platform | Description | Example / Format |
|---|---|---|---|
| `KEYSTORE_BASE64` | Android | Base64-encoded Android release keystore (`.jks`) | Contents of `keystore_base64.txt` |
| `KEYSTORE_PASSWORD` | Android | Password for the release keystore | Your keystore password (`ChangeMe123!`) |
| `KEY_ALIAS` | Android / Win | Key alias inside the keystore / PFX | `snapgrove` |
| `KEY_PASSWORD` | Android | Password for the private key alias | Your private key password (`ChangeMe123!`) |
| `WINDOWS_CERT_BASE64` | Windows | Base64-encoded Windows Code-Signing PFX | Contents of `windows_cert_base64.txt` |
| `WINDOWS_CERT_PASSWORD` | Windows | Password for the Windows PFX certificate | Your PFX password (`ChangeMe123!`) |
| `RELEASE_VERIFY_PRIVATE_KEY` | All | Private RSA key used by CI/CD to sign `SHA256SUMS.txt` | PEM formatted string from `verify-private.pem` |

---

## 2. Generating Release & Verification Keys

Run the key generator script in the project root:

```powershell
# On Windows (PowerShell)
.\scripts\generate-keys.ps1

# On Linux / macOS (Bash)
./scripts/generate-keys.sh
```

This generates:
1. `upload-keystore.jks` & `android/key.properties` (Android signing key & local Gradle config)
2. `snapgrove-windows.pfx` & `snapgrove-windows.cer` (Windows Authenticode code-signing PFX & public certificate)
3. `keystore_base64.txt` & `windows_cert_base64.txt` (Ready to paste into GitHub Secrets)
4. `verify-private.pem` (CI/CD verification key -> copy to `RELEASE_VERIFY_PRIVATE_KEY` secret)
5. `scripts/snapgrove-release.pub` (Public key distributed with GitHub Releases)

> [!CAUTION]
> Never commit `*.jks`, `*.pfx`, `key.properties`, or `verify-private.pem` into Git. All private key files and secrets are automatically ignored in `.gitignore`.

---

## 3. Creating a Release

Whenever you're ready to cut a release:

1. **Ensure release notes exist**:
   Create `.github/releases/<version>.md` (e.g. `.github/releases/1.7.42.md` or `.github/releases/1.8.0-alpha.1.md`).
2. **Run the local release script**:
   ```powershell
   .\scripts\release.ps1
   ```
   The script will:
   - Ask whether this is a **Stable** or **Alpha** release.
   - Prompt or confirm the version number (e.g., `1.7.42`).
   - Validate that `.github/releases/<version>.md` exists.
   - Run tests and static analysis.
   - Create the Git tag and push it to GitHub.
3. **CI/CD Automation**:
   Pushing the tag triggers `.github/workflows/release.yml`, which builds universal & ABI-split APKs, signs them, computes cryptographic checksums, and attaches all assets to the GitHub Release.

---

## 4. End-User Release Verification

Users can independently verify that their downloaded APK or Windows package was produced by the official CI/CD pipeline and has not been tampered with:

```powershell
# Windows
.\scripts\verify-release.ps1 -Apk Snapgrove-1.7.42-universal.apk

# Linux / macOS
./scripts/verify-release.sh Snapgrove-1.7.42-universal.apk
```

---

## 5. Windows Code Signing & Free Options Guide

On Windows, executables are subject to **Microsoft Defender SmartScreen** ("Windows protected your PC — Unknown Publisher").

### Option A: Self-Signed Certificate (Default Included)
1. `snapgrove-windows.pfx` signs the binary via `signtool.exe` in CI/CD.
2. To allow users or developers to trust it on a local PC, run:
   ```powershell
   Import-Certificate -FilePath snapgrove-windows.cer -CertStoreLocation Cert:\CurrentUser\Root
   ```
   Once imported, Windows displays **"Verified Publisher: Snapgrove Open Source"** and SmartScreen allows execution without prompts.

### Option B: SignPath Foundation (100% Free for Open Source Projects)
- **SignPath Foundation** provides free, publicly-trusted code-signing certificates (backed by a genuine CA) to open-source GitHub projects.
- **Benefits:** No SmartScreen warning, zero recurring cost, automated signing in GitHub Actions via `SignPath/github-action-submit-signing-request`.
- **How to apply:** Sign up at [signpath.org/open-source](https://signpath.org/open-source).

### Option C: Microsoft Store Submission
- Package as an MSIX application.
- Microsoft automatically signs the application with their trusted root certificate when submitted to the Microsoft Store.
- One-time individual developer account registration fee is ~$19 (no recurring annual certificate renewal fee). Users install with 0 warnings via Store or `winget install snapgrove`.
