# Script to generate Android release keystore, Windows code-signing cert, and CI/CD verification keypair
param (
    [string]$KeystoreName = "upload-keystore.jks",
    [string]$KeyAlias = "snapgrove",
    [string]$KeyPassword = "ChangeMe123!",
    [string]$WindowsCertName = "snapgrove-windows.pfx",
    [string]$WindowsCertPassword = "ChangeMe123!",
    [string]$ValidityDays = "10000"
)

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "   Snapgrove Keypair & Credentials Generator   " -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

# 1. Generate Android Keystore
if (-not (Test-Path $KeystoreName)) {
    Write-Host "`n[1/3] Generating Android Release Keystore ($KeystoreName)..." -ForegroundColor Yellow
    keytool -genkey -v -keystore $KeystoreName -alias $KeyAlias `
        -keyalg RSA -keysize 2048 -validity $ValidityDays `
        -storepass $KeyPassword -keypass $KeyPassword `
        -dname "CN=Snapgrove, OU=Mobile, O=Snapgrove, L=City, S=State, C=US"
    
    Write-Host "  ✓ Android Keystore generated: $KeystoreName" -ForegroundColor Green
} else {
    Write-Host "`n[1/3] Android Keystore $KeystoreName already exists." -ForegroundColor Gray
}

# Base64 output for GitHub Secrets
$keystoreBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $KeystoreName))
$base64Keystore = [System.Convert]::ToBase64String($keystoreBytes)
Set-Content -Path "keystore_base64.txt" -Value $base64Keystore
Write-Host "  -> Base64 string saved to keystore_base64.txt (Copy to KEYSTORE_BASE64 secret)" -ForegroundColor Green

# Generate android/key.properties for local Gradle builds
$keyPropsContent = @"
storePassword=$KeyPassword
keyPassword=$KeyPassword
keyAlias=$KeyAlias
storeFile=../$KeystoreName
"@
Set-Content -Path "android/key.properties" -Value $keyPropsContent
Write-Host "  -> Local config written to android/key.properties" -ForegroundColor Green

# 2. Generate Windows Code-Signing Certificate (PFX)
if (-not (Test-Path $WindowsCertName)) {
    Write-Host "`n[2/3] Generating Windows Code-Signing PFX ($WindowsCertName)..." -ForegroundColor Yellow
    keytool -genkeypair -v -keystore $WindowsCertName -storetype PKCS12 `
        -alias $KeyAlias -keyalg RSA -keysize 2048 -validity $ValidityDays `
        -storepass $WindowsCertPassword -keypass $WindowsCertPassword `
        -dname "CN=Snapgrove Open Source, O=Snapgrove, C=US" `
        -ext "EKU=codeSigning"
    
    Write-Host "  ✓ Windows PFX generated: $WindowsCertName" -ForegroundColor Green
} else {
    Write-Host "`n[2/3] Windows PFX $WindowsCertName already exists." -ForegroundColor Gray
}

# Export public certificate (.cer) from PFX for users / system trust
keytool -exportcert -keystore $WindowsCertName -storetype PKCS12 `
    -alias $KeyAlias -storepass $WindowsCertPassword `
    -file "snapgrove-windows.cer" -rfc 2>$null
if (Test-Path "snapgrove-windows.cer") {
    Write-Host "  -> Public certificate exported to snapgrove-windows.cer" -ForegroundColor Green
}

# Base64 output for Windows GitHub Secrets
$pfxBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $WindowsCertName))
$base64Pfx = [System.Convert]::ToBase64String($pfxBytes)
Set-Content -Path "windows_cert_base64.txt" -Value $base64Pfx
Write-Host "  -> Base64 string saved to windows_cert_base64.txt (Copy to WINDOWS_CERT_BASE64 secret)" -ForegroundColor Green

# 3. Generate CI/CD Release Verification Keypair (OpenSSL)
Write-Host "`n[3/3] Generating Cryptographic Release Verification Keypair..." -ForegroundColor Yellow
$opensslCmd = Get-Command openssl -ErrorAction SilentlyContinue
$opensslPath = if ($opensslCmd) { $opensslCmd.Source } else { $null }
if (-not $opensslPath -and (Test-Path "C:\Program Files\Git\usr\bin\openssl.exe")) {
    $opensslPath = "C:\Program Files\Git\usr\bin\openssl.exe"
}

if ($opensslPath) {
    & $opensslPath genrsa -out "verify-private.pem" 2048 2>$null
    & $opensslPath rsa -in "verify-private.pem" -pubout -out "scripts/snapgrove-release.pub" 2>$null
    Write-Host "  ✓ Private key generated: verify-private.pem (Copy to RELEASE_VERIFY_PRIVATE_KEY secret)" -ForegroundColor Green
    Write-Host "  ✓ Public key generated:  scripts/snapgrove-release.pub" -ForegroundColor Green
} else {
    Write-Warning "OpenSSL command not found. You can generate verification keys on Linux/macOS using ./scripts/generate-keys.sh."
}

Write-Host "`nDone! All keys generated and protected in .gitignore." -ForegroundColor Cyan
