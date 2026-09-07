#requires -Version 5.1
<#
.SYNOPSIS
    Local quality gate for unslop-windows developers and AI agents.
    Runs:
      [1/5] AST Syntax & Parser Verification (unslop.ps1 + scripts/*.ps1)
      [2/5] Static Code Analysis (PSScriptAnalyzer error/warning scan)
      [3/5] Line-Ending & File Integrity Audit (CRLF for .bat/.ps1, merge conflicts)
      [4/5] Safe Non-Elevated Dry-Run Execution Test (.\unslop.ps1 -DryRun)
      [5/5] Symmetrical Restoration Dry-Run Execution Test (.\unslop.ps1 -Undo -DryRun)
    Exit code 0 = Safe to push to main, 1+ = Gate blocked; fix reported findings first.

.PARAMETER Fast
    Skips the execution-based DryRun tests (runs syntax, analyzer, and file integrity only).

.PARAMETER SkipAnalyzer
    Bypasses PSScriptAnalyzer if the module is not installed locally.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts/Test-MasterGate.ps1
    powershell -ExecutionPolicy Bypass -File scripts/Test-MasterGate.ps1 -Fast
#>
[CmdletBinding()]
param(
    [switch]$Fast,
    [switch]$SkipAnalyzer
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$fail = $false
$totalSteps = if ($Fast) { 3 } else { 5 }

# Resolve best PowerShell executable for subprocess execution
$psExec = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell.exe" }

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  unslop-windows: Local Master Quality Gate" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ------------------------------------------------------------
# STEP 1: AST Syntax & Parser Verification
# ------------------------------------------------------------
Write-Host "`n[1/$totalSteps] AST syntax & parser verification..." -ForegroundColor Yellow
$scriptFiles = Get-ChildItem -Path $root -Include *.ps1, *.psm1, *.psd1 -Recurse -File |
    Where-Object { $_.FullName -notmatch '\\(logs|\.git|videos)\\' }

$syntaxErrorsFound = 0
foreach ($file in $scriptFiles) {
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$parseErrors) | Out-Null
    if ($parseErrors -and $parseErrors.Count -gt 0) {
        $syntaxErrorsFound += $parseErrors.Count
        $fail = $true
        Write-Host "  [SYNTAX ERROR] $($file.Name):" -ForegroundColor Red
        foreach ($err in $parseErrors) {
            Write-Host "    Line $($err.Extent.StartLineNumber): $($err.Message)" -ForegroundColor Red
        }
    }
}

if ($syntaxErrorsFound -eq 0) {
    Write-Host "  PASSED: All $($scriptFiles.Count) PowerShell scripts parsed clean with 0 syntax errors." -ForegroundColor Green
} else {
    Write-Host "  FAILED: Found $syntaxErrorsFound syntax errors." -ForegroundColor Red
}

# ------------------------------------------------------------
# STEP 2: Static Code Analysis (PSScriptAnalyzer)
# ------------------------------------------------------------
Write-Host "`n[2/$totalSteps] Static code analysis (PSScriptAnalyzer)..." -ForegroundColor Yellow
if (-not $SkipAnalyzer) {
    $analyzerModule = Get-Module -ListAvailable -Name PSScriptAnalyzer -ErrorAction SilentlyContinue
    if ($analyzerModule) {
        try {
            $analyzerResults = Invoke-ScriptAnalyzer -Path $root -Recurse -Severity Error, Warning |
                Where-Object { $_.ScriptPath -notmatch '\\(logs|\.git|videos)\\' }

            $errors = $analyzerResults | Where-Object { $_.Severity -eq 'Error' }
            $warnings = $analyzerResults | Where-Object { $_.Severity -eq 'Warning' }

            if ($errors -and $errors.Count -gt 0) {
                $fail = $true
                Write-Host "  FAILED: PSScriptAnalyzer found $($errors.Count) blocking errors:" -ForegroundColor Red
                $errors | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Red
            } elseif ($warnings -and $warnings.Count -gt 0) {
                Write-Host "  NOTICE: PSScriptAnalyzer found $($warnings.Count) non-blocking warnings:" -ForegroundColor Yellow
                $warnings | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Yellow
                Write-Host "  PASSED: 0 blocking errors found." -ForegroundColor Green
            } else {
                Write-Host "  PASSED: PSScriptAnalyzer clean scan, 0 issues found." -ForegroundColor Green
            }
        } catch {
            Write-Host "  WARNING: ScriptAnalyzer execution encountered an error: $_" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  SKIPPED: PSScriptAnalyzer module is not installed locally." -ForegroundColor DarkGray
        Write-Host "  (To install: Install-Module PSScriptAnalyzer -Scope CurrentUser)" -ForegroundColor DarkGray
    }
} else {
    Write-Host "  SKIPPED: -SkipAnalyzer parameter supplied." -ForegroundColor DarkGray
}

# ------------------------------------------------------------
# STEP 3: Line-Ending & File Integrity Audit
# ------------------------------------------------------------
Write-Host "`n[3/$totalSteps] Line-ending & file integrity audit..." -ForegroundColor Yellow
$lineEndingFail = $false

# Verify unslop.bat has CRLF line endings
$unslopBat = Join-Path $root "unslop.bat"
if (Test-Path $unslopBat) {
    $batBytes = [System.IO.File]::ReadAllBytes($unslopBat)
    # Check for naked LF (LF not preceded by CR)
    $hasNakedLf = $false
    for ($i = 0; $i -lt $batBytes.Length; $i++) {
        if ($batBytes[$i] -eq 10) { # LF
            if ($i -eq 0 -or $batBytes[$i - 1] -ne 13) { # Not preceded by CR
                $hasNakedLf = $true
                break
            }
        }
    }
    if ($hasNakedLf) {
        $lineEndingFail = $true
        Write-Host "  FAILED: unslop.bat contains LF line endings without CR (must be CRLF for Windows cmd.exe)." -ForegroundColor Red
    } else {
        Write-Host "  PASSED: unslop.bat line endings normalized (CRLF)." -ForegroundColor Green
    }
}

# Check for merge conflict markers across text files
$textFiles = Get-ChildItem -Path $root -Include *.ps1, *.bat, *.md, *.yml -Recurse -File |
    Where-Object { $_.FullName -notmatch '\\(logs|\.git|videos)\\' }

$conflictMarkers = @()
foreach ($tf in $textFiles) {
    $content = Get-Content -Path $tf.FullName -Raw -ErrorAction SilentlyContinue
    if ($content -and ($content -match '(?m)^<{7}\s' -or $content -match '(?m)^={7}$' -or $content -match '(?m)^>{7}\s')) {
        $conflictMarkers += $tf.Name
    }
}

if ($conflictMarkers.Count -gt 0) {
    $lineEndingFail = $true
    Write-Host "  FAILED: Merge conflict markers detected in: $($conflictMarkers -join ', ')" -ForegroundColor Red
} else {
    Write-Host "  PASSED: 0 merge conflict markers detected across $($textFiles.Count) files." -ForegroundColor Green
}

if ($lineEndingFail) { $fail = $true }

# ------------------------------------------------------------
# STEP 4: Safe Non-Elevated Dry-Run Execution Test
# ------------------------------------------------------------
if (-not $Fast) {
    Write-Host "`n[4/$totalSteps] Safe non-elevated Dry-Run execution test..." -ForegroundColor Yellow
    Push-Location $root
    try {
        $dryRunOut = & $psExec -NoProfile -ExecutionPolicy Bypass -File ".\unslop.ps1" -DryRun 2>&1
        $dryExit = $LASTEXITCODE
        if ($dryExit -ne 0) {
            $fail = $true
            Write-Host "  FAILED: unslop.ps1 -DryRun exited with code $dryExit" -ForegroundColor Red
            Write-Host ($dryRunOut | Select-Object -Last 15 | Out-String) -ForegroundColor Red
        } else {
            $summaryFound = ($dryRunOut -match "UNSLOP-WINDOWS: DEBLOAT & HARDEN COMPLETE").Length -gt 0
            if ($summaryFound) {
                Write-Host "  PASSED: unslop.ps1 -DryRun completed successfully (code 0, all 18 modules verified)." -ForegroundColor Green
            } else {
                $fail = $true
                Write-Host "  FAILED: unslop.ps1 -DryRun completed without expected completion banner." -ForegroundColor Red
            }
        }
    } finally { Pop-Location }

    # ------------------------------------------------------------
    # STEP 5: Symmetrical Restoration Dry-Run Execution Test
    # ------------------------------------------------------------
    Write-Host "`n[5/$totalSteps] Symmetrical restoration Dry-Run execution test..." -ForegroundColor Yellow
    Push-Location $root
    try {
        $undoOut = & $psExec -NoProfile -ExecutionPolicy Bypass -File ".\unslop.ps1" -Undo -DryRun 2>&1
        $undoExit = $LASTEXITCODE
        if ($undoExit -ne 0) {
            $fail = $true
            Write-Host "  FAILED: unslop.ps1 -Undo -DryRun exited with code $undoExit" -ForegroundColor Red
            Write-Host ($undoOut | Select-Object -Last 15 | Out-String) -ForegroundColor Red
        } else {
            $undoSummaryFound = ($undoOut -match "RESTORE / UNDO COMPLETE").Length -gt 0
            if ($undoSummaryFound) {
                Write-Host "  PASSED: unslop.ps1 -Undo -DryRun completed successfully (code 0, symmetrical restore verified)." -ForegroundColor Green
            } else {
                $fail = $true
                Write-Host "  FAILED: unslop.ps1 -Undo -DryRun completed without expected restore banner." -ForegroundColor Red
            }
        }
    } finally { Pop-Location }
} else {
    Write-Host "`n[4-5/$totalSteps] Skipped DryRun tests (-Fast flag specified)." -ForegroundColor DarkGray
}

$sw.Stop()
$elapsed = [math]::Round($sw.Elapsed.TotalSeconds, 1)
Write-Host ""
if ($fail) {
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host "  == MASTER GATE BLOCKED (${elapsed}s) - Fix findings before pushing ==  " -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Red
    exit 1
} else {
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "  == MASTER GATE PASSED (${elapsed}s) - Safe to push to main ==  " -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    exit 0
}
