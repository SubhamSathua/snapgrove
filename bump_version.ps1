# Snapgrove Version Manager (xx.yy.zz+iteration)
param (
    [ValidateSet("major", "minor", "patch", "custom", "")]
    [string]$Type = "",
    [string]$CustomVersion = "",
    [string]$CommitMessage = "",
    [switch]$NoPush
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$PubspecPath = Join-Path $ScriptDir "pubspec.yaml"
$HistoryPath = Join-Path $ScriptDir "version_history.json"

if (-not (Test-Path $PubspecPath)) {
    Write-Error "pubspec.yaml not found at $PubspecPath"
    exit 1
}

# 1. Read current version from pubspec.yaml
$pubspecContent = Get-Content -Path $PubspecPath -Raw
if ($pubspecContent -match "version:\s*([0-9\.]+)(?:\+([0-9]+))?") {
    $rawVersion = $Matches[1]
    $rawIteration = if ($Matches[2]) { [int]$Matches[2] } else { 1 }
} else {
    $rawVersion = "01.00.00"
    $rawIteration = 1
}

# Parse xx.yy.zz
$versionParts = $rawVersion.Split('.')
$currentMajor = if ($versionParts.Length -gt 0) { [int]$versionParts[0] } else { 1 }
$currentMinor = if ($versionParts.Length -gt 1) { [int]$versionParts[1] } else { 0 }
$currentPatch = if ($versionParts.Length -gt 2) { [int]$versionParts[2] } else { 0 }

# 2. Read internal iteration history
$history = @()
if (Test-Path $HistoryPath) {
    try {
        $historyJson = Get-Content -Path $HistoryPath -Raw
        $history = ConvertFrom-Json $historyJson
        if ($history -isnot [System.Collections.IEnumerable]) {
            $history = @($history)
        }
    } catch {
        $history = @()
    }
}

$formattedCurrent = "{0:D2}.{1:D2}.{2:D2}" -f $currentMajor, $currentMinor, $currentPatch

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "       SNAPGROVE VERSION MANAGER         " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Current Version   : $formattedCurrent" -ForegroundColor Yellow
Write-Host " Current Iteration : $rawIteration" -ForegroundColor Yellow
Write-Host " Total Iterations  : $($history.Count)" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan

# 3. Determine bump type
$selectedType = $Type.ToLower()
if ([string]::IsNullOrWhiteSpace($selectedType)) {
    Write-Host ""
    Write-Host "Select version bump type:" -ForegroundColor Green
    Write-Host " [1] Major  (xx+1 . 00 . 00) - Breaking / Major milestone"
    Write-Host " [2] Minor  (xx . yy+1 . 00) - New features"
    Write-Host " [3] Patch  (xx . yy . zz+1) - Bug fixes and tweaks"
    Write-Host " [4] Custom (manual xx.yy.zz input)"
    Write-Host " [Q] Cancel"
    Write-Host ""
    
    $choice = Read-Host "Enter option [1-4 or Q]"
    switch ($choice.Trim()) {
        "1" { $selectedType = "major" }
        "2" { $selectedType = "minor" }
        "3" { $selectedType = "patch" }
        "4" { $selectedType = "custom" }
        "Q" { Write-Host "Aborted."; exit 0 }
        "q" { Write-Host "Aborted."; exit 0 }
        default {
            Write-Error "Invalid selection: '$choice'"
            exit 1
        }
    }
}

$newMajor = $currentMajor
$newMinor = $currentMinor
$newPatch = $currentPatch

switch ($selectedType) {
    "major" {
        $newMajor = $currentMajor + 1
        $newMinor = 0
        $newPatch = 0
    }
    "minor" {
        $newMinor = $currentMinor + 1
        $newPatch = 0
    }
    "patch" {
        $newPatch = $currentPatch + 1
    }
    "custom" {
        $inputVer = $CustomVersion
        while ([string]::IsNullOrWhiteSpace($inputVer)) {
            $inputVer = Read-Host "Enter custom version (format: xx.yy.zz or x.y.z)"
        }
        
        if ($inputVer -notmatch "^\s*(\d{1,2})\.(\d{1,2})\.(\d{1,2})\s*$") {
            Write-Error "Invalid version format '$inputVer'. Expected format like '01.02.03' or '1.2.3'."
            exit 1
        }
        $newMajor = [int]$Matches[1]
        $newMinor = [int]$Matches[2]
        $newPatch = [int]$Matches[3]
    }
}

$newIteration = $rawIteration + 1
$newVersionFormatted = "{0:D2}.{1:D2}.{2:D2}" -f $newMajor, $newMinor, $newPatch
$newFullVersion = "$newVersionFormatted+$newIteration"

Write-Host ""
Write-Host "Target Version   : $newVersionFormatted (Build #$newIteration)" -ForegroundColor Green
Write-Host "Full Spec String : $newFullVersion" -ForegroundColor Green
Write-Host ""

# 4. Update pubspec.yaml
$updatedPubspec = $pubspecContent -replace "version:\s*[0-9\.]+(?:\+[0-9]+)?", "version: $newFullVersion"
Set-Content -Path $PubspecPath -Value $updatedPubspec -Encoding UTF8
Write-Host "[OK] Updated pubspec.yaml" -ForegroundColor Green

# 5. Update version_history.json
$historyEntry = [PSCustomObject]@{
    iteration     = $newIteration
    version       = $newVersionFormatted
    fullVersion   = $newFullVersion
    bumpType      = $selectedType
    previous      = "$formattedCurrent+$rawIteration"
    timestamp     = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
}

$historyList = [System.Collections.Generic.List[object]]::new()
foreach ($item in $history) {
    $historyList.Add($item)
}
$historyList.Add($historyEntry)

$historyJsonOutput = $historyList | ConvertTo-Json -Depth 5
Set-Content -Path $HistoryPath -Value $historyJsonOutput -Encoding UTF8
Write-Host "[OK] Updated internal iteration tracking in version_history.json" -ForegroundColor Green

# 6. Git commit and push
$defaultMsg = "chore: bump version to $newVersionFormatted (Build #$newIteration)"
if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
    if ([string]::IsNullOrWhiteSpace($Type)) {
        $userMsg = Read-Host "Enter commit message (press Enter for default: '$defaultMsg')"
        if ([string]::IsNullOrWhiteSpace($userMsg)) {
            $CommitMessage = $defaultMsg
        } else {
            $CommitMessage = $userMsg
        }
    } else {
        $CommitMessage = $defaultMsg
    }
}

Write-Host ""
Write-Host "Staging changes with git add..." -ForegroundColor Cyan
git add -A

Write-Host "Committing: $CommitMessage" -ForegroundColor Cyan
git commit -m "$CommitMessage"

if (-not $NoPush) {
    Write-Host "Pushing to remote repository..." -ForegroundColor Cyan
    $currentBranch = (git branch --show-current).Trim()
    if ([string]::IsNullOrWhiteSpace($currentBranch)) {
        $currentBranch = "main"
    }
    git push origin $currentBranch
    Write-Host "[OK] Successfully pushed to origin/$currentBranch!" -ForegroundColor Green
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "       VERSION BUMP COMPLETED            " -ForegroundColor Green
Write-Host " New Version: $newVersionFormatted+$newIteration" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
