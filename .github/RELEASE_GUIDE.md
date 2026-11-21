# Snapgrove Release Management & Credentials Guide

This guide outlines how to configure GitHub Secrets, sign Android APKs, verify release signatures, and run the automated release workflow.

---

## 1. Credentials & Secrets Configuration

To enable automated release signing and cryptographic integrity verification in GitHub Actions, configure the following repository secrets under **Settings > Secrets and variables > Actions**:

| Secret Name | Description | Example / Format |
|---|---|---|
| `KEYSTORE_BASE64` | Base64-encoded Android release keystore (`.jks`) | Output of `[Convert]::ToBase64String([IO.File]::ReadAllBytes('upload-keystore.jks'))` |
| `KEYSTORE_PASSWORD` | Password for the release keystore | Your keystore password |
| `KEY_ALIAS` | Key alias inside the keystore | `snapgrove` |
| `KEY_PASSWORD` | Password for the private key alias | Your private key password |
| `RELEASE_VERIFY_PRIVATE_KEY` | Private RSA/Ed25519 key used by CI/CD to sign `SHA256SUMS.txt` | PEM formatted private key string |

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
1. `upload-keystore.jks` (Android signing key)
2. `verify-private.pem` (CI/CD verification key -> copy to `RELEASE_VERIFY_PRIVATE_KEY` secret)
3. `scripts/snapgrove-release.pub` (Public key distributed with GitHub Releases)

> [!CAUTION]
> Never commit `upload-keystore.jks` or `verify-private.pem` into Git. Both are ignored in `.gitignore`.

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

Users can independently verify that their downloaded APK was produced by the official CI/CD pipeline and has not been tampered with:

```powershell
# Windows
.\scripts\verify-release.ps1 -Apk Snapgrove-1.7.42-universal.apk

# Linux / macOS
./scripts/verify-release.sh Snapgrove-1.7.42-universal.apk
```
