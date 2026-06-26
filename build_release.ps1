# build_release.ps1
# Increments version in pubspec.yaml, then runs flutter build appbundle --release.
# On build failure the version is rolled back automatically.
#
# Usage:
#   .\build_release.ps1           # patch++ and build++ (default)
#   .\build_release.ps1 -Minor    # minor++, patch=0, build++
#   .\build_release.ps1 -Major    # major++, minor=0, patch=0, build++
#   .\build_release.ps1 -DryRun   # preview only, no changes

param(
    [switch]$Minor,
    [switch]$Major,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$pubspecPath = Join-Path $PSScriptRoot "pubspec.yaml"

if (-not (Test-Path $pubspecPath)) {
    Write-Host "ERROR: pubspec.yaml not found at $pubspecPath" -ForegroundColor Red
    exit 1
}

$content = [System.IO.File]::ReadAllText($pubspecPath, [System.Text.Encoding]::UTF8)

if ($content -notmatch 'version:\s+(\d+)\.(\d+)\.(\d+)\+(\d+)') {
    Write-Host "ERROR: Cannot parse version from pubspec.yaml" -ForegroundColor Red
    Write-Host "       Expected format:  version: 1.2.3+45" -ForegroundColor DarkGray
    exit 1
}

[int]$verMajor = $Matches[1]
[int]$verMinor = $Matches[2]
[int]$verPatch = $Matches[3]
[int]$verBuild = $Matches[4]

$oldVersion = "$verMajor.$verMinor.$verPatch+$verBuild"

if ($Major) {
    $verMajor++; $verMinor = 0; $verPatch = 0
} elseif ($Minor) {
    $verMinor++; $verPatch = 0
} else {
    $verPatch++
}
$verBuild++

$newVersion = "$verMajor.$verMinor.$verPatch+$verBuild"

Write-Host ""
Write-Host "  pubspec.yaml version:" -ForegroundColor DarkGray
Write-Host "    $oldVersion  ->  $newVersion" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "  DryRun: no changes made." -ForegroundColor Yellow
    exit 0
}

$newContent = $content -replace 'version:\s+\d+\.\d+\.\d+\+\d+', "version: $newVersion"
[System.IO.File]::WriteAllText($pubspecPath, $newContent, [System.Text.Encoding]::UTF8)

Write-Host "  Version bumped. Starting build..." -ForegroundColor Green
Write-Host ""

flutter build appbundle --release

$exitCode = $LASTEXITCODE

Write-Host ""
if ($exitCode -eq 0) {
    $aabPath = Join-Path $PSScriptRoot "build\app\outputs\bundle\release\app-release.aab"
    Write-Host "  Build succeeded!" -ForegroundColor Green
    Write-Host "  Version : $newVersion" -ForegroundColor Cyan
    Write-Host "  AAB     : $aabPath" -ForegroundColor Cyan
    Write-Host ""

    # Auto-update Firestore min_version so old app versions are blocked on next upload
    $semver = "$verMajor.$verMinor.$verPatch"
    $updaterScript = Join-Path $PSScriptRoot "tool\update_firestore_version.js"
    Write-Host "  Updating Firestore min_version -> $semver ..." -ForegroundColor DarkGray
    node $updaterScript $semver
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Firestore updated." -ForegroundColor Green
    } else {
        Write-Host "  WARNING: Firestore update failed (update manually in Firebase Console)." -ForegroundColor Yellow
    }
    Write-Host ""
} else {
    Write-Host "  Build FAILED -- rolling back to $oldVersion" -ForegroundColor Red
    $rolled = $newContent -replace 'version:\s+\d+\.\d+\.\d+\+\d+', "version: $oldVersion"
    [System.IO.File]::WriteAllText($pubspecPath, $rolled, [System.Text.Encoding]::UTF8)
    Write-Host "  pubspec.yaml restored." -ForegroundColor DarkGray
    Write-Host ""
    exit 1
}
