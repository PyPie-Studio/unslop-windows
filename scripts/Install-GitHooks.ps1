#requires -Version 5.1
<#
.SYNOPSIS
    Configures git hooks for unslop-windows repository.
    Enables local quality gate enforcement prior to pushing to protected branches.

.PARAMETER Test
    Immediately tests the pre-push hook after installation.

.PARAMETER Fast
    When used with -Test, runs the gate in -Fast mode.

.PARAMETER Uninstall
    Removes the git hooks configuration and deletes installed hook copies.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts/Install-GitHooks.ps1
    powershell -ExecutionPolicy Bypass -File scripts/Install-GitHooks.ps1 -Test
    powershell -ExecutionPolicy Bypass -File scripts/Install-GitHooks.ps1 -Uninstall
#>
[CmdletBinding()]
param(
    [switch]$Test,
    [switch]$Fast,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  unslop-windows: Git Hooks Setup" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Verify git is available
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: 'git' command not found in PATH." -ForegroundColor Red
    exit 1
}

Push-Location $root
try {
    # Verify inside a git repository
    $gitDir = git rev-parse --git-dir 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Not inside a git repository." -ForegroundColor Red
        exit 1
    }

    if ($Uninstall) {
        Write-Host "Uninstalling unslop-windows git hooks..." -ForegroundColor Yellow
        git config --unset core.hooksPath 2>$null

        $targetHook = Join-Path $root ".git\hooks\pre-push"
        if (Test-Path $targetHook) {
            Remove-Item $targetHook -Force
            Write-Host "  Removed: .git/hooks/pre-push" -ForegroundColor DarkGray
        }

        Write-Host "SUCCESS: Git hooks uninstalled. core.hooksPath reset to default." -ForegroundColor Green
        return
    }

    $sourceHookDir = Join-Path $root ".githooks"
    $sourceHook = Join-Path $sourceHookDir "pre-push"

    if (-not (Test-Path $sourceHook)) {
        Write-Host "ERROR: Pre-push hook file not found at: $sourceHook" -ForegroundColor Red
        exit 1
    }

    # 1. Configure git core.hooksPath to .githooks
    Write-Host "Configuring git core.hooksPath to .githooks..." -ForegroundColor Yellow
    git config core.hooksPath .githooks
    $configuredPath = git config core.hooksPath
    Write-Host "  core.hooksPath = $configuredPath" -ForegroundColor Green

    # 2. Also copy to .git/hooks for tools that bypass core.hooksPath
    $gitHooksDir = Join-Path $root ".git\hooks"
    if (Test-Path $gitHooksDir) {
        $destHook = Join-Path $gitHooksDir "pre-push"
        Copy-Item -Path $sourceHook -Destination $destHook -Force
        Write-Host "  Synchronized fallback to: .git/hooks/pre-push" -ForegroundColor Green
    }

    Write-Host "SUCCESS: Pre-push hook is active and protecting 'main' and 'master' branches." -ForegroundColor Green

    # 3. Optional Test execution
    if ($Test) {
        Write-Host "`nTesting pre-push hook pipeline..." -ForegroundColor Yellow
        $gateScript = Join-Path $PSScriptRoot "Test-MasterGate.ps1"
        $psExec = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell.exe" }
        if ($Fast) {
            & $psExec -NoProfile -ExecutionPolicy Bypass -File $gateScript -Fast
        } else {
            & $psExec -NoProfile -ExecutionPolicy Bypass -File $gateScript
        }

        if ($LASTEXITCODE -eq 0) {
            Write-Host "`nHook test verification: PASSED" -ForegroundColor Green
        } else {
            Write-Host "`nHook test verification: FAILED (Exit Code $LASTEXITCODE)" -ForegroundColor Red
            exit $LASTEXITCODE
        }
    } else {
        Write-Host "`nTip: To test the gate immediately, run:" -ForegroundColor DarkGray
        Write-Host "  powershell -ExecutionPolicy Bypass -File scripts/Install-GitHooks.ps1 -Test" -ForegroundColor DarkGray
    }
}
finally {
    Pop-Location
}
