# Script to generate Android release keystore and CI/CD verification keypair
param (
    [string]$KeystoreName = "upload-keystore.jks",
    [string]$KeyAlias = "snapgrove",
    [string]$KeyPassword = "ChangeMe123!",
    [string]$ValidityDays = "10000"
)

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "   Snapgrove Keypair & Credentials Generator   " -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

# 1. Generate Android Keystore
if (-not (Test-Path $KeystoreName)) {
    Write-Host "`n[1/2] Generating Android Release Keystore ($KeystoreName)..." -ForegroundColor Yellow
    keytool -genkey -v -keystore $KeystoreName -alias $KeyAlias `
        -keyalg RSA -keysize 2048 -validity $ValidityDays `
        -storepass $KeyPassword -keypass $KeyPassword `
        -dname "CN=Snapgrove, OU=Mobile, O=Snapgrove, L=City, S=State, C=US"
    
    Write-Host "  ✓ Keystore generated: $KeystoreName" -ForegroundColor Green
} else {
    Write-Host "`n[1/2] Keystore $KeystoreName already exists." -ForegroundColor Gray
}

# Base64 output for GitHub Secrets
$keystoreBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $KeystoreName))
$base64Keystore = [System.Convert]::ToBase64String($keystoreBytes)
Set-Content -Path "keystore_base64.txt" -Value $base64Keystore
Write-Host "  -> Base64 string saved to keystore_base64.txt (Copy to KEYSTORE_BASE64 secret)" -ForegroundColor Green

# 2. Generate CI/CD Release Verification Keypair (OpenSSL)
Write-Host "`n[2/2] Generating Cryptographic Release Verification Keypair..." -ForegroundColor Yellow
$openssl = Get-Command openssl -ErrorAction SilentlyContinue
if ($openssl) {
    & openssl genrsa -out "verify-private.pem" 2048
    & openssl rsa -in "verify-private.pem" -pubout -out "scripts/snapgrove-release.pub"
    Write-Host "  ✓ Private key generated: verify-private.pem (Copy to RELEASE_VERIFY_PRIVATE_KEY secret)" -ForegroundColor Green
    Write-Host "  ✓ Public key generated:  scripts/snapgrove-release.pub" -ForegroundColor Green
} else {
    Write-Warning "OpenSSL command not found. You can generate keys on Linux/macOS using ./scripts/generate-keys.sh."
}

Write-Host "`nDone! Add keys to .gitignore and configure repository secrets." -ForegroundColor Cyan
