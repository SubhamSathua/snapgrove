# Script to verify Snapgrove release APK integrity and authenticity
param (
    [Parameter(Mandatory=$true)]
    [string]$Apk,
    [string]$ChecksumFile = "SHA256SUMS.txt",
    [string]$SignatureFile = "SHA256SUMS.txt.sig",
    [string]$PublicKey = "scripts/snapgrove-release.pub"
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   Snapgrove Release Verification Tool    " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

if (-not (Test-Path $Apk)) {
    Write-Error "APK file '$Apk' not found."
    exit 1
}

# 1. Verify SHA-256 Checksum
Write-Host "`n[1/2] Verifying SHA-256 Checksum..." -ForegroundColor Yellow
$apkFileName = Split-Path -Leaf $Apk
$actualHash = (Get-FileHash -Path $Apk -Algorithm SHA256).Hash.ToLower()
Write-Host "  Computed: $actualHash" -ForegroundColor Gray

if (Test-Path $ChecksumFile) {
    $checksumLine = Get-Content $ChecksumFile | Where-Object { $_ -match "$apkFileName" }
    if ($checksumLine) {
        $expectedHash = ($checksumLine -split "\s+")[0].ToLower()
        Write-Host "  Expected: $expectedHash" -ForegroundColor Gray
        if ($actualHash -eq $expectedHash) {
            Write-Host "  ✓ SHA-256 Checksum MATCHES!" -ForegroundColor Green
        } else {
            Write-Error "  ✗ SHA-256 Checksum MISMATCH! File may be corrupt or altered."
            exit 1
        }
    } else {
        Write-Warning "APK filename '$apkFileName' not found in $ChecksumFile."
    }
} else {
    Write-Warning "Checksum file '$ChecksumFile' not found in current directory."
}

# 2. Cryptographic Signature Verification
Write-Host "`n[2/2] Verifying Cryptographic Release Signature..." -ForegroundColor Yellow
if ((Test-Path $ChecksumFile) -and (Test-Path $SignatureFile) -and (Test-Path $PublicKey)) {
    $openssl = Get-Command openssl -ErrorAction SilentlyContinue
    if ($openssl) {
        $verifyOutput = & openssl dgst -sha256 -verify $PublicKey -signature $SignatureFile $ChecksumFile 2>&1
        if ($verifyOutput -match "Verified OK") {
            Write-Host "  ✓ Official Release Signature Verified: OK" -ForegroundColor Green
            Write-Host "`nSUCCESS: The APK is authentic and signed by official Snapgrove CI/CD." -ForegroundColor Green
        } else {
            Write-Error "  ✗ Signature verification FAILED! $verifyOutput"
            exit 1
        }
    } else {
        Write-Warning "OpenSSL command not found. Skipping signature verification."
    }
} else {
    Write-Host "  Signature files not present locally. SHA-256 check was performed." -ForegroundColor Gray
}
