<#
.SYNOPSIS
    Packages and publishes an official unslop-windows release to GitHub Releases.
.DESCRIPTION
    Extracts release notes from CHANGELOG.md for the specified tag, packages the
    distribution zip archive, generates GNU-compatible SHA256SUMS.txt, and creates
    or updates the GitHub release via GitHub CLI ('gh').
.PARAMETER Tag
    The git tag to release (e.g. 'v1.0.5'). If omitted, uses the latest git tag.
#>
[CmdletBinding()]
param(
    [string]$Tag
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Error "GitHub CLI ('gh') is required but not installed or not in PATH."
    }

    if (-not $Tag) {
        $Tag = (git describe --tags --abbrev=0 2>$null).Trim()
        if (-not $Tag) {
            Write-Error "No git tags found in repository."
        }
    }

    $version = $Tag -replace '^v', ''
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  unslop-windows: Publishing Release $Tag" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    $zipName = "unslop-windows-$Tag.zip"
    $notesFile = "RELEASE_NOTES.md"
    $checksumFile = "SHA256SUMS.txt"

    Write-Host "`n[1/4] Packaging release distribution bundle ($zipName)..." -ForegroundColor Yellow
    $includePaths = @("unslop.bat", "unslop.ps1", "README.md", "LICENSE", "scripts", "docs", "tests") |
        Where-Object { Test-Path (Join-Path $root $_) }
    Compress-Archive -Path $includePaths -DestinationPath (Join-Path $root $zipName) -Force
    Write-Host "  Archive size: $([math]::Round((Get-Item (Join-Path $root $zipName)).Length / 1KB, 1)) KB" -ForegroundColor Green

    Write-Host "`n[2/4] Generating cryptographic SHA-256 checksums..." -ForegroundColor Yellow
    $filesToHash = @($zipName, "unslop.ps1", "unslop.bat")
    $checksums = foreach ($f in $filesToHash) {
        $hash = (Get-FileHash -Path (Join-Path $root $f) -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash  $f"
    }
    $checksums | Set-Content -Path (Join-Path $root $checksumFile) -Encoding utf8
    $checksums | ForEach-Object { Write-Host "  $_" -ForegroundColor Cyan }

    Write-Host "`n[3/4] Extracting release notes from CHANGELOG.md..." -ForegroundColor Yellow
    $changelogPath = Join-Path $root "CHANGELOG.md"
    $notesBody = ""
    if (Test-Path $changelogPath) {
        $changelog = Get-Content $changelogPath -Raw
        $pattern = "(?s)## \[$version\].*?(?=(?:\r?\n## \[|\Z))"
        if ($changelog -match $pattern) {
            $extracted = $matches[0].Trim()
            $notesBody = ($extracted -replace "^##\s+\[.*?\]\s*-\s*\d{4}-\d{2}-\d{2}", "" -replace "\r?\n---\s*$", "").Trim()
        }
    }

    if (-not $notesBody) {
        $notesBody = "Official production release $Tag."
    }

    $header = "# 🛡️ unslop-windows $Tag`n`n$notesBody`n`n---`n`n"
    $footer = @"
## 📦 Quick Installation & Usage

1. Download **``unslop-windows-$Tag.zip``** from Assets below.
2. Extract the archive to any directory.
3. Right-click **``unslop.bat``** and choose **Run as administrator** (or double-click and accept the UAC elevation prompt).
4. Select an option from the interactive menu:
   - **[1] Full Debloat**: Purge OneDrive, telemetry, diagnostics & provisioned bloatware.
   - **[2] Dry-Run Audit**: Inspect all changes safely with zero system modifications.
   - **[3] Debloat, Keep Microsoft To-Do**: Full debloat preserving To-Do.
   - **[4] Debloat, Keep Xbox**: Full debloat preserving Xbox Identity Provider & gaming services.
   - **[5] Debloat, Keep OneDrive**: Full debloat preserving Microsoft OneDrive sync.
   - **[6] Debloat + Classic Context Menu**: Full debloat and restore Windows 10 classic context menu.
   - **[7] Custom Flags**: Supply custom switch combinations (e.g. ``-KeepTodos -KeepXbox -NoRestart``).
   - **[8] Full Restore / Undo**: Symmetrically revert all tweaks, services, tasks, and policies back to Windows defaults.

---

## 🔒 Verification & Integrity
Verify archive integrity using the published ``SHA256SUMS.txt``:
````powershell
Get-FileHash .\unslop-windows-$Tag.zip -Algorithm SHA256
````
"@

    Set-Content -Path (Join-Path $root $notesFile) -Value ($header + $footer) -Encoding utf8
    Write-Host "  Generated release notes for $Tag ($(($header + $footer).Length) chars)." -ForegroundColor Green

    Write-Host "`n[4/4] Publishing release to GitHub..." -ForegroundColor Yellow
    $exists = & gh release view $Tag 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Updating existing release $Tag..." -ForegroundColor Cyan
        gh release edit $Tag --notes-file (Join-Path $root $notesFile)
        gh release upload $Tag (Join-Path $root $zipName) (Join-Path $root $checksumFile) --clobber
    } else {
        Write-Host "  Creating new GitHub release $Tag..." -ForegroundColor Cyan
        gh release create $Tag (Join-Path $root $zipName) (Join-Path $root $checksumFile) --title "$Tag" --notes-file (Join-Path $root $notesFile)
    }

    Write-Host "`nSUCCESS: Release $Tag is published live on GitHub!" -ForegroundColor Green
    Write-Host "  URL: https://github.com/PyPie-Studio/unslop-windows/releases/tag/$Tag" -ForegroundColor Cyan
}
finally {
    # Clean up local release artifacts
    $cleanupFiles = @($zipName, $notesFile, $checksumFile)
    foreach ($cf in $cleanupFiles) {
        if ($cf -and (Test-Path (Join-Path $root $cf))) {
            Remove-Item (Join-Path $root $cf) -Force -ErrorAction SilentlyContinue
        }
    }
    Pop-Location
}
