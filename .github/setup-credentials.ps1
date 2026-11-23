# Snapgrove Credentials & Key Generator for GitHub Actions CI/CD
# This script can be run from the repository root or from the .github/ directory.

$rootDir = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path "$rootDir\pubspec.yaml")) {
    $rootDir = Get-Location
}

Set-Location $rootDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   Snapgrove GitHub CI/CD Credentials & Keys Setup       " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Configuration Loading
$configFile = "$rootDir\signing-config.json"
$textConfigFile = "$rootDir\publisher-info.txt"

$winPublisher = "Snapgrove Open Source"
$winOrg = "Snapgrove"
$winCountry = "US"
$winPass = "ChangeMe123!"
$winPfx = "$rootDir\snapgrove-windows.pfx"
$winValidity = "10000"

$androidFile = "$rootDir\upload-keystore.jks"
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

if (Test-Path $configFile) {
    Write-Host "[i] Reading config: signing-config.json" -ForegroundColor Green
    $json = Get-Content $configFile -Raw | ConvertFrom-Json
    if ($json.windows) {
        if ($json.windows.publisherName) { $winPublisher = $json.windows.publisherName }
        if ($json.windows.organization) { $winOrg = $json.windows.organization }
        if ($json.windows.country) { $winCountry = $json.windows.country }
        if ($json.windows.password) { $winPass = $json.windows.password }
        if ($json.windows.validityDays) { $winValidity = "$($json.windows.validityDays)" }
    }
    if ($json.android) {
        if ($json.android.keyAlias) { $androidAlias = $json.android.keyAlias }
        if ($json.android.storePassword) { $androidStorePass = $json.android.storePassword }
        if ($json.android.keyPassword) { $androidKeyPass = $json.android.keyPassword }
        if ($json.android.commonName) { $androidCN = $json.android.commonName }
        if ($json.android.organization) { $androidOrg = $json.android.organization }
        if ($json.android.country) { $androidCountry = $json.android.country }
        if ($json.android.validityDays) { $androidValidity = "$($json.android.validityDays)" }
    }
} elseif (Test-Path $textConfigFile) {
    Write-Host "[i] Reading config: publisher-info.txt" -ForegroundColor Green
    Get-Content $textConfigFile | ForEach-Object {
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
    Write-Host "[!] No custom config found; copying template to signing-config.json..." -ForegroundColor Yellow
    if (Test-Path "$rootDir\signing-config.example.json") {
        Copy-Item "$rootDir\signing-config.example.json" -Destination $configFile
    }
}

Write-Host "  -> Publisher: $winPublisher" -ForegroundColor Gray
Write-Host "  -> Alias:     $androidAlias" -ForegroundColor Gray

# 2. Android Keystore
Write-Host "`n[1/3] Generating Android Release Keystore..." -ForegroundColor Yellow
if (-not (Test-Path $androidFile)) {
    $dname = "CN=$androidCN, OU=$androidOU, O=$androidOrg, L=$androidCity, ST=$androidState, C=$androidCountry"
    keytool -genkey -v -keystore $androidFile -alias $androidAlias `
        -keyalg RSA -keysize 2048 -validity $androidValidity `
        -storepass $androidStorePass -keypass $androidKeyPass `
        -dname $dname
    Write-Host "  ✓ Created $androidFile" -ForegroundColor Green
} else {
    Write-Host "  ✓ Keystore exists: $androidFile" -ForegroundColor Green
}

$androidBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path $androidFile)))
Set-Content -Path "$rootDir\keystore_base64.txt" -Value $androidBase64

$keyProps = @"
storePassword=$androidStorePass
keyPassword=$androidKeyPass
keyAlias=$androidAlias
storeFile=../upload-keystore.jks
"@
Set-Content -Path "$rootDir\android\key.properties" -Value $keyProps

# 3. Windows Code-Signing PFX
Write-Host "`n[2/3] Generating Windows Authenticode Certificate (PFX)..." -ForegroundColor Yellow
if (-not (Test-Path $winPfx)) {
    $winDname = "CN=$winPublisher, O=$winOrg, C=$winCountry"
    keytool -genkeypair -v -keystore $winPfx -storetype PKCS12 `
        -alias $androidAlias -keyalg RSA -keysize 2048 -validity $winValidity `
        -storepass $winPass -keypass $winPass `
        -dname $winDname `
        -ext "EKU=codeSigning"
    Write-Host "  ✓ Created $winPfx" -ForegroundColor Green
} else {
    Write-Host "  ✓ PFX exists: $winPfx" -ForegroundColor Green
}

keytool -exportcert -keystore $winPfx -storetype PKCS12 `
    -alias $androidAlias -storepass $winPass `
    -file "$rootDir\snapgrove-windows.cer" -rfc 2>$null
if (Test-Path "$rootDir\snapgrove-windows.cer") {
    Write-Host "  ✓ Exported public certificate: snapgrove-windows.cer" -ForegroundColor Green
}

$pfxBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path $winPfx)))
Set-Content -Path "$rootDir\windows_cert_base64.txt" -Value $pfxBase64

# 4. Cryptographic Release Verification Keypair (OpenSSL)
Write-Host "`n[3/3] Generating Cryptographic Verification Keypair..." -ForegroundColor Yellow
$opensslCmd = Get-Command openssl -ErrorAction SilentlyContinue
$opensslPath = if ($opensslCmd) { $opensslCmd.Source } else { $null }
if (-not $opensslPath -and (Test-Path "C:\Program Files\Git\usr\bin\openssl.exe")) {
    $opensslPath = "C:\Program Files\Git\usr\bin\openssl.exe"
}

if ($opensslPath) {
    if (-not (Test-Path "$rootDir\verify-private.pem")) {
        & $opensslPath genrsa -out "$rootDir\verify-private.pem" 2048 2>$null
        & $opensslPath rsa -in "$rootDir\verify-private.pem" -pubout -out "$rootDir\scripts\snapgrove-release.pub" 2>$null
        Write-Host "  ✓ Generated verification keypair: verify-private.pem & scripts/snapgrove-release.pub" -ForegroundColor Green
    } else {
        Write-Host "  ✓ Verification keypair exists." -ForegroundColor Green
    }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "   SUCCESS! Copy these Secrets to GitHub Repository      " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Go to: GitHub Repo > Settings > Secrets and variables > Actions`n" -ForegroundColor White
Write-Host "1. KEYSTORE_BASE64" -ForegroundColor Yellow
Write-Host "   -> Content of '$rootDir\keystore_base64.txt'`n"
Write-Host "2. KEYSTORE_PASSWORD" -ForegroundColor Yellow
Write-Host "   -> $androidStorePass`n"
Write-Host "3. KEY_ALIAS" -ForegroundColor Yellow
Write-Host "   -> $androidAlias`n"
Write-Host "4. KEY_PASSWORD" -ForegroundColor Yellow
Write-Host "   -> $androidKeyPass`n"
Write-Host "5. WINDOWS_CERT_BASE64" -ForegroundColor Yellow
Write-Host "   -> Content of '$rootDir\windows_cert_base64.txt'`n"
Write-Host "6. WINDOWS_CERT_PASSWORD" -ForegroundColor Yellow
Write-Host "   -> $winPass`n"
Write-Host "7. RELEASE_VERIFY_PRIVATE_KEY" -ForegroundColor Yellow
Write-Host "   -> Content of '$rootDir\verify-private.pem'`n"
Write-Host "See .github/steps.md for complete step-by-step documentation." -ForegroundColor Cyan
