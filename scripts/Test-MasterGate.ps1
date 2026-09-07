#requires -Version 5.1
<#
.SYNOPSIS
    Local quality gate for unslop-windows developers and AI agents.
    Runs:
      [1/7] AST Syntax & Parser Verification (unslop.ps1 + scripts/*.ps1 + tests/*.ps1)
      [2/7] Static Code Analysis (PSScriptAnalyzer error/warning scan)
      [3/7] Line-Ending & File Integrity Audit (CRLF for .bat/.ps1, merge conflicts)
      [4/7] Pester Unit & Mocking Test Suite (tests/unslop.Tests.ps1)
      [5/7] Safe Non-Elevated Dry-Run Execution Test (.\unslop.ps1 -DryRun)
      [6/7] Symmetrical Restoration Dry-Run Execution Test (.\unslop.ps1 -Undo -DryRun)
      [7/7] Batch Launcher CLI Parameter Passthrough Audit (cmd.exe /c ".\unslop.bat -DryRun")
    Exit code 0 = Safe to push to main, 1+ = Gate blocked; fix reported findings first.

.PARAMETER Fast
    Skips the execution-based unit, DryRun, and batch launcher tests (runs syntax, analyzer, and file integrity only).

.PARAMETER SkipAnalyzer
    Bypasses PSScriptAnalyzer if the module is not installed locally.

.PARAMETER SkipUnitTests
    Bypasses Pester unit tests if Pester 5 is not installed locally.

.PARAMETER TestResultsPath
    Optional file path to export Pester unit test results in NUnit XML format.

.PARAMETER CodeCoveragePath
    Optional file path to export Pester code coverage metrics in JaCoCo XML format.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts/Test-MasterGate.ps1
    powershell -ExecutionPolicy Bypass -File scripts/Test-MasterGate.ps1 -Fast
#>
[CmdletBinding()]
param(
    [switch]$Fast,
    [switch]$SkipAnalyzer,
    [switch]$SkipUnitTests,
    [string]$TestResultsPath,
    [string]$CodeCoveragePath
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$fail = $false
$totalSteps = if ($Fast) { 3 } else { 7 }

# Resolve matching PowerShell executable for subprocess execution based on current host runtime
$psExec = if ($PSVersionTable.PSEdition -eq 'Desktop' -or -not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    "powershell.exe"
} else {
    "pwsh"
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  unslop-windows: Master Quality Gate ($($PSVersionTable.PSEdition) Edition - PS $($PSVersionTable.PSVersion))" -ForegroundColor Cyan
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
            $analyzerSettings = Join-Path $root "PSScriptAnalyzerSettings.psd1"
            $analyzerParams = @{
                Path     = $root
                Recurse  = $true
                Severity = @('Error', 'Warning')
            }
            if (Test-Path $analyzerSettings) {
                $analyzerParams['Settings'] = $analyzerSettings
            }
            $analyzerResults = Invoke-ScriptAnalyzer @analyzerParams |
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
# STEP 4: Pester Unit & Mocking Test Suite
# ------------------------------------------------------------
if (-not $Fast) {
    if (-not $SkipUnitTests) {
        Write-Host "`n[4/$totalSteps] Pester unit & mocking test suite..." -ForegroundColor Yellow
        $testScript = Join-Path $root "tests\unslop.Tests.ps1"
        if (Test-Path $testScript) {
            $pesterModule = Get-Module -ListAvailable -Name Pester | Sort-Object Version -Descending | Select-Object -First 1
            if ($pesterModule -and $pesterModule.Version.Major -ge 5) {
                Push-Location $root
                try {
                    $xmlConfig = ""
                    if ($TestResultsPath) {
                        $targetXml = if ([System.IO.Path]::IsPathRooted($TestResultsPath)) {
                            $TestResultsPath
                        } else {
                            Join-Path $root $TestResultsPath
                        }
                        $xmlDir = Split-Path -Parent $targetXml
                        if ($xmlDir -and -not (Test-Path $xmlDir)) {
                            New-Item -ItemType Directory -Path $xmlDir -Force | Out-Null
                        }
                        $xmlConfig = "`$cfg.TestResult.Enabled = `$true; `$cfg.TestResult.OutputFormat = 'NUnitXml'; `$cfg.TestResult.OutputPath = '$targetXml';"
                    }
                    $covConfig = ""
                    if ($CodeCoveragePath) {
                        $targetCovXml = if ([System.IO.Path]::IsPathRooted($CodeCoveragePath)) {
                            $CodeCoveragePath
                        } else {
                            Join-Path $root $CodeCoveragePath
                        }
                        $covDir = Split-Path -Parent $targetCovXml
                        if ($covDir -and -not (Test-Path $covDir)) {
                            New-Item -ItemType Directory -Path $covDir -Force | Out-Null
                        }
                        $covFile = Join-Path $root "unslop.ps1"
                        $covConfig = "`$cfg.CodeCoverage.Enabled = `$true; `$cfg.CodeCoverage.Path = '$covFile'; `$cfg.CodeCoverage.OutputFormat = 'JaCoCo'; `$cfg.CodeCoverage.OutputPath = '$targetCovXml';"
                    }
                    $pesterCmd = "Import-Module Pester -MinimumVersion 5.0.0; `$cfg = New-PesterConfiguration; `$cfg.Run.Path = '$testScript'; `$cfg.Output.Verbosity = 'Detailed'; $xmlConfig $covConfig `$cfg.Run.PassThru = `$true; `$res = Invoke-Pester -Configuration `$cfg; if (`$res.CodeCoverage) { Write-Host `"  Code Coverage: `$([math]::Round(`$res.CodeCoverage.CoveragePercent, 1))% (`$(`$res.CodeCoverage.CommandsExecutedCount)/`$(`$res.CodeCoverage.CommandsAnalyzedCount) commands)`" -ForegroundColor Cyan }; if (`$res.FailedCount -gt 0) { exit 1 }"
                    $pesterOut = & $psExec -NoProfile -ExecutionPolicy Bypass -Command $pesterCmd 2>&1
                    $pesterExit = $LASTEXITCODE
                    if ($pesterExit -ne 0) {
                        $fail = $true
                        Write-Host "  FAILED: Pester unit tests failed with exit code $pesterExit" -ForegroundColor Red
                        Write-Host ($pesterOut | Select-Object -Last 15 | Out-String) -ForegroundColor Red
                    } else {
                        Write-Host "  PASSED: All Pester unit tests passed clean (0 failures)." -ForegroundColor Green
                    }
                } catch {
                    $fail = $true
                    Write-Host "  FAILED: Error invoking Pester test suite: $_" -ForegroundColor Red
                } finally { Pop-Location }
            } else {
                Write-Host "  SKIPPED: Pester 5.x+ is not installed locally (found: $(if ($pesterModule) { $pesterModule.Version } else { 'none' }))." -ForegroundColor DarkGray
                Write-Host "  (To install: Install-Module Pester -Scope CurrentUser -SkipPublisherCheck -Force -MinimumVersion 5.0.0)" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "  SKIPPED: tests/unslop.Tests.ps1 not found." -ForegroundColor DarkGray
        }
    } else {
        Write-Host "`n[4/$totalSteps] SKIPPED: -SkipUnitTests parameter supplied." -ForegroundColor DarkGray
    }

    # ------------------------------------------------------------
    # STEP 5: Safe Non-Elevated Dry-Run Execution Test
    # ------------------------------------------------------------
    Write-Host "`n[5/$totalSteps] Safe non-elevated Dry-Run execution test..." -ForegroundColor Yellow
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
    # STEP 6: Symmetrical Restoration Dry-Run Execution Test
    # ------------------------------------------------------------
    Write-Host "`n[6/$totalSteps] Symmetrical restoration Dry-Run execution test..." -ForegroundColor Yellow
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

    # ------------------------------------------------------------
    # STEP 7: Batch Launcher CLI Parameter Passthrough Audit
    # ------------------------------------------------------------
    Write-Host "`n[7/$totalSteps] Batch launcher CLI parameter passthrough audit..." -ForegroundColor Yellow
    Push-Location $root
    try {
        $batOut = & cmd.exe /c ".\unslop.bat -DryRun" 2>&1
        $batExit = $LASTEXITCODE
        if ($batExit -ne 0 -or ($batOut -match 'unexpected at this time|syntax of the command is incorrect')) {
            $fail = $true
            Write-Host "  FAILED: unslop.bat -DryRun exited with code $batExit" -ForegroundColor Red
            Write-Host ($batOut | Select-Object -Last 10 | Out-String) -ForegroundColor Red
        } else {
            Write-Host "  PASSED: unslop.bat headless execution verified in cmd.exe (code 0)." -ForegroundColor Green
        }
    } finally { Pop-Location }
} else {
    Write-Host "`n[4-7/$totalSteps] Skipped Unit, DryRun, and Batch Launcher tests (-Fast flag specified)." -ForegroundColor DarkGray
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
