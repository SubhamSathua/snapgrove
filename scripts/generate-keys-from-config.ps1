# Script to generate Android release keystore & Windows code-signing cert from JSON or Text config
param (
    [string]$ConfigFile = "signing-config.json",
    [string]$TextConfigFile = "publisher-info.txt"
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   Snapgrove Keypair Generator (Config-Driven)           " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Load Configuration
$winPublisher = "Snapgrove Open Source"
$winOrg = "Snapgrove"
$winCountry = "US"
$winPass = "ChangeMe123!"
$winPfx = "snapgrove-windows.pfx"
$winValidity = "10000"

$androidFile = "upload-keystore.jks"
$androidAlias = "snapgrove"
$androidStorePass = "ChangeMe123!"
$androidKeyPass = "ChangeMe123!"
$androidCN = "Snapgrove"
$androidOU = "Mobile"
$androidOrg = "Snapgrove"
$androidCity = "City"
$androidState = "State"
$androidCountry = "US"
$androidValidity = "10000"

if (Test-Path $ConfigFile) {
    Write-Host "Loading configuration from JSON: $ConfigFile" -ForegroundColor Green
    $json = Get-Content $ConfigFile -Raw | ConvertFrom-Json
    if ($json.windows) {
        if ($json.windows.publisherName) { $winPublisher = $json.windows.publisherName }
        if ($json.windows.organization) { $winOrg = $json.windows.organization }
        if ($json.windows.country) { $winCountry = $json.windows.country }
        if ($json.windows.password) { $winPass = $json.windows.password }
        if ($json.windows.pfxFileName) { $winPfx = $json.windows.pfxFileName }
        if ($json.windows.validityDays) { $winValidity = "$($json.windows.validityDays)" }
    }
    if ($json.android) {
        if ($json.android.keystoreFileName) { $androidFile = $json.android.keystoreFileName }
        if ($json.android.keyAlias) { $androidAlias = $json.android.keyAlias }
        if ($json.android.storePassword) { $androidStorePass = $json.android.storePassword }
        if ($json.android.keyPassword) { $androidKeyPass = $json.android.keyPassword }
        if ($json.android.commonName) { $androidCN = $json.android.commonName }
        if ($json.android.organizationUnit) { $androidOU = $json.android.organizationUnit }
        if ($json.android.organization) { $androidOrg = $json.android.organization }
        if ($json.android.city) { $androidCity = $json.android.city }
        if ($json.android.state) { $androidState = $json.android.state }
        if ($json.android.country) { $androidCountry = $json.android.country }
        if ($json.android.validityDays) { $androidValidity = "$($json.android.validityDays)" }
    }
} elseif (Test-Path $TextConfigFile) {
    Write-Host "Loading configuration from plain text: $TextConfigFile" -ForegroundColor Green
    Get-Content $TextConfigFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $parts = $line.Split("=", 2)
            $key = $parts[0].Trim().ToUpper()
            $val = $parts[1].Trim()
            switch ($key) {
                "WIN_PUBLISHER_NAME" { $winPublisher = $val }
                "WIN_ORGANIZATION"   { $winOrg = $val }
                "WIN_COUNTRY"        { $winCountry = $val }
                "WIN_PASSWORD"       { $winPass = $val }
                "WIN_PFX_FILE"       { $winPfx = $val }
                "ANDROID_KEYSTORE_FILE" { $androidFile = $val }
                "ANDROID_KEY_ALIAS"  { $androidAlias = $val }
                "ANDROID_STORE_PASS" { $androidStorePass = $val }
                "ANDROID_KEY_PASS"   { $androidKeyPass = $val }
                "ANDROID_CN"         { $androidCN = $val }
                "ANDROID_ORG"        { $androidOrg = $val }
                "ANDROID_COUNTRY"    { $androidCountry = $val }
            }
        }
    }
} else {
    Write-Host "No custom config found; creating default template '$ConfigFile'..." -ForegroundColor Yellow
    if (Test-Path "signing-config.example.json") {
        Copy-Item "signing-config.example.json" -Destination $ConfigFile
    }
    Write-Host "Using default publisher settings. You can edit '$ConfigFile' anytime." -ForegroundColor Gray
}

Write-Host "`nTarget Windows Publisher : $winPublisher" -ForegroundColor White
Write-Host "Target Android Keystore  : $androidFile ($androidAlias)" -ForegroundColor White

# 2. Generate Android Keystore
Write-Host "`n[1/3] Processing Android Release Keystore..." -ForegroundColor Yellow
if (-not (Test-Path $androidFile)) {
    $dname = "CN=$androidCN, OU=$androidOU, O=$androidOrg, L=$androidCity, ST=$androidState, C=$androidCountry"
    keytool -genkey -v -keystore $androidFile -alias $androidAlias `
        -keyalg RSA -keysize 2048 -validity $androidValidity `
        -storepass $androidStorePass -keypass $androidKeyPass `
        -dname $dname
    Write-Host "  ✓ Generated Android Keystore: $androidFile" -ForegroundColor Green
} else {
    Write-Host "  ✓ Existing Android Keystore found: $androidFile" -ForegroundColor Green
}

# Android Base64 output & key.properties
$androidBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $androidFile))
$androidBase64 = [System.Convert]::ToBase64String($androidBytes)
Set-Content -Path "keystore_base64.txt" -Value $androidBase64
Write-Host "  -> Base64 saved to keystore_base64.txt (for GitHub Secret KEYSTORE_BASE64)" -ForegroundColor Green

$keyProps = @"
storePassword=$androidStorePass
keyPassword=$androidKeyPass
keyAlias=$androidAlias
storeFile=../$androidFile
"@
Set-Content -Path "android/key.properties" -Value $keyProps
Write-Host "  -> Configured android/key.properties for Gradle builds" -ForegroundColor Green

# 3. Generate Windows Authenticode Code-Signing PFX
Write-Host "`n[2/3] Processing Windows Authenticode Certificate (PFX)..." -ForegroundColor Yellow
if (-not (Test-Path $winPfx)) {
    $winDname = "CN=$winPublisher, O=$winOrg, C=$winCountry"
    keytool -genkeypair -v -keystore $winPfx -storetype PKCS12 `
        -alias $androidAlias -keyalg RSA -keysize 2048 -validity $winValidity `
        -storepass $winPass -keypass $winPass `
        -dname $winDname `
        -ext "EKU=codeSigning"
    Write-Host "  ✓ Generated Windows PFX: $winPfx" -ForegroundColor Green
} else {
    Write-Host "  ✓ Existing Windows PFX found: $winPfx" -ForegroundColor Green
}

# Export public certificate (.cer)
keytool -exportcert -keystore $winPfx -storetype PKCS12 `
    -alias $androidAlias -storepass $winPass `
    -file "snapgrove-windows.cer" -rfc 2>$null
if (Test-Path "snapgrove-windows.cer") {
    Write-Host "  -> Public certificate exported: snapgrove-windows.cer" -ForegroundColor Green
}

# Windows Base64 output
$pfxBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $winPfx))
$pfxBase64 = [System.Convert]::ToBase64String($pfxBytes)
Set-Content -Path "windows_cert_base64.txt" -Value $pfxBase64
Write-Host "  -> Base64 saved to windows_cert_base64.txt (for GitHub Secret WINDOWS_CERT_BASE64)" -ForegroundColor Green

# 4. Generate CI/CD Release Verification Keypair (OpenSSL)
Write-Host "`n[3/3] Processing CI/CD Release Verification Keypair..." -ForegroundColor Yellow
$opensslCmd = Get-Command openssl -ErrorAction SilentlyContinue
$opensslPath = if ($opensslCmd) { $opensslCmd.Source } else { $null }
if (-not $opensslPath -and (Test-Path "C:\Program Files\Git\usr\bin\openssl.exe")) {
    $opensslPath = "C:\Program Files\Git\usr\bin\openssl.exe"
}

if ($opensslPath) {
    if (-not (Test-Path "verify-private.pem")) {
        & $opensslPath genrsa -out "verify-private.pem" 2048 2>$null
        & $opensslPath rsa -in "verify-private.pem" -pubout -out "scripts/snapgrove-release.pub" 2>$null
        Write-Host "  ✓ Generated verification keypair: verify-private.pem & scripts/snapgrove-release.pub" -ForegroundColor Green
    } else {
        Write-Host "  ✓ Existing verification keypair found." -ForegroundColor Green
    }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "   Setup Complete! Keys generated & gitignored.           " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "To enable CI/CD automated signing, set these GitHub Secrets:" -ForegroundColor White
Write-Host "  KEYSTORE_BASE64       <- Copy from keystore_base64.txt"
Write-Host "  KEYSTORE_PASSWORD     <- $androidStorePass"
Write-Host "  KEY_ALIAS             <- $androidAlias"
Write-Host "  KEY_PASSWORD          <- $androidKeyPass"
Write-Host "  WINDOWS_CERT_BASE64   <- Copy from windows_cert_base64.txt"
Write-Host "  WINDOWS_CERT_PASSWORD <- $winPass"
Write-Host "  RELEASE_VERIFY_PRIVATE_KEY <- Copy from verify-private.pem"
