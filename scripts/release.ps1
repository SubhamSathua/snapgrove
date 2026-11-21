# Local Release Management Script for Snapgrove
param (
    [string]$Version,
    [string]$Channel = "stable" # "stable" or "alpha"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Snapgrove Release Management Tool    " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. Check Working Tree
$status = git status --porcelain
if ($status) {
    Write-Warning "Working tree has uncommitted changes. Please commit or stash before creating a release."
    git status -s
    $continue = Read-Host "Proceed anyway? (y/N)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        exit 1
    }
}

# 2. Select Release Channel
if (-not $Channel -or ($Channel -ne "stable" -and $Channel -ne "alpha")) {
    Write-Host "`nSelect Release Channel:" -ForegroundColor Yellow
    Write-Host "  1) Stable (Production release)"
    Write-Host "  2) Alpha (Pre-release testing)"
    $choice = Read-Host "Choice [1-2]"
    if ($choice -eq "2") {
        $Channel = "alpha"
    } else {
        $Channel = "stable"
    }
}

# 3. Determine Version
if (-not $Version) {
    # Extract current version from pubspec.yaml
    $pubspec = Get-Content "pubspec.yaml" -Raw
    if ($pubspec -match "version:\s*([0-9]+\.[0-9]+\.[0-9]+)") {
        $detectedVersion = $matches[1]
    } else {
        $detectedVersion = "1.7.42"
    }
    
    if ($Channel -eq "alpha") {
        $defaultTag = "$detectedVersion-alpha.1"
    } else {
        $defaultTag = $detectedVersion
    }
    
    $inputVersion = Read-Host "`nEnter Release Version/Tag (default: $defaultTag)"
    if ($inputVersion) {
        $Version = $inputVersion
    } else {
        $Version = $defaultTag
    }
}

# 4. Validate Version Format
if ($Version -notmatch "^v?[0-9]+\.[0-9]+\.[0-9]+") {
    Write-Error "Invalid version format '$Version'. Expected semver like '1.7.42' or '1.7.42-alpha.1'."
    exit 1
}

# Clean tag (strip leading v for release note file lookup)
$cleanVersion = $Version.TrimStart("v")
$noteFile = ".github/releases/$cleanVersion.md"

if (-not (Test-Path $noteFile)) {
    Write-Warning "Release note file '$noteFile' does not exist!"
    $create = Read-Host "Would you like to create a template release note now? (y/N)"
    if ($create -eq "y" -or $create -eq "Y") {
        New-Item -ItemType Directory -Force -Path ".github/releases" | Out-Null
        $template = @"
Hey everyone! Welcome to Snapgrove $cleanVersion. 🥳

### What's New
- Added new features and performance enhancements.
- Bug fixes and UI refinements.

Enjoy organizing! 😎
"@
        Set-Content -Path $noteFile -Value $template
        Write-Host "Created $noteFile template. Please review and edit before releasing." -ForegroundColor Green
    } else {
        Write-Error "Release cancelled: missing release notes file '$noteFile'."
        exit 1
    }
}

Write-Host "`nRelease Note Preview ($noteFile):" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor DarkGray
Get-Content $noteFile | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
Write-Host "----------------------------------------" -ForegroundColor DarkGray

# 5. Confirmation
Write-Host "`nReady to release:" -ForegroundColor Yellow
Write-Host "  Tag:     $Version" -ForegroundColor White
Write-Host "  Channel: $Channel" -ForegroundColor White
Write-Host "  Notes:   $noteFile" -ForegroundColor White

$confirm = Read-Host "`nCreate tag '$Version' and push to origin? (y/N)"
if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "Release aborted." -ForegroundColor Yellow
    exit 0
}

# 6. Tag and Push
Write-Host "`nCreating Git tag '$Version'..." -ForegroundColor Green
git tag -a "$Version" -m "Release $Version ($Channel)"

$push = Read-Host "Push tag '$Version' to remote now to trigger CI/CD? (y/N)"
if ($push -eq "y" -or $push -eq "Y") {
    Write-Host "Pushing tag to origin..." -ForegroundColor Green
    git push origin "$Version"
    Write-Host "`nTag pushed successfully! GitHub Actions is now building and publishing the release." -ForegroundColor Cyan
} else {
    Write-Host "`nTag created locally. Push manually when ready via: git push origin $Version" -ForegroundColor Yellow
}
