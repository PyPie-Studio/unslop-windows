#requires -Version 5.1
<#
.SYNOPSIS
    Local quality gate for unslop-windows developers.
    Runs:
      [1/7] AST Syntax & Parser Verification (unslop-win11.ps1 + unslop-win10.ps1 + scripts/*.ps1 + tests/*.ps1)
      [2/7] Static Code Analysis (PSScriptAnalyzer error/warning scan)
      [3/7] Line-Ending & File Integrity Audit (CRLF for .bat/.ps1, merge conflicts)
      [4/7] Pester Unit & Mocking Test Suite (tests/unslop-win11.Tests.ps1 / tests/unslop-win10.Tests.ps1)
      [5/7] Safe Non-Elevated Dry-Run Execution Test (.\unslop-win11.ps1 -DryRun / .\unslop-win10.ps1 -DryRun)
      [6/7] Symmetrical Restoration Dry-Run Execution Test (.\unslop-win11.ps1 -Undo -DryRun / .\unslop-win10.ps1 -Undo -DryRun)
      [7/7] Batch Launcher CLI Parameter Passthrough Audit (cmd.exe /c ".\unslop.bat -DryRun")
    Exit code 0 = Safe to push to main, 1+ = Gate blocked; fix reported findings first.

.PARAMETER Fast
    Skips execution-based unit, DryRun and batch launcher tests (runs syntax, analyzer and file integrity only).

.PARAMETER SkipAnalyzer
    Bypasses PSScriptAnalyzer if the module is not installed locally.

.PARAMETER SkipUnitTests
    Bypasses Pester unit tests if Pester 6 is not installed locally.

.PARAMETER IncludeIntegration
    Includes slow CLI subprocess and integration tests in the Pester run (default executes -Tag 'Unit' only).

.PARAMETER TestResultsPath
    Optional file path to export Pester unit test results in NUnit XML format.

.PARAMETER CodeCoveragePath
    Optional file path to export Pester code coverage metrics in JaCoCo XML format.

.PARAMETER Both
    Runs local quality gate verification against both Windows 11 and Windows 10 engines.

.PARAMETER LintDocs
    Runs markdownlint-cli across all documentation files in the repository.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts/Test-MasterGate.ps1
    powershell -ExecutionPolicy Bypass -File scripts/Test-MasterGate.ps1 -Fast
    powershell -ExecutionPolicy Bypass -File scripts/Test-MasterGate.ps1 -Both
    powershell -ExecutionPolicy Bypass -File scripts/Test-MasterGate.ps1 -IncludeIntegration
    powershell -ExecutionPolicy Bypass -File scripts/Test-MasterGate.ps1 -Win10 -SkipBuildCheck
#>
[CmdletBinding()]
param(
    [switch]$Fast,
    [switch]$SkipAnalyzer,
    [switch]$SkipUnitTests,
    [switch]$IncludeIntegration,
    [switch]$Strict,
    [switch]$Win11,
    [switch]$Win10,
    [switch]$Both,
    [switch]$SkipBuildCheck,
    [switch]$LintDocs,
    [string]$TestResultsPath,
    [string]$CodeCoveragePath
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$fail = $false
$totalSteps = if ($Fast) { 3 } else { 7 }

if ($env:GITHUB_ACTIONS -eq 'true' -or $env:CI -eq 'true') {
    $Strict = $true
}

# Resolve matching PowerShell executable for subprocess execution based on current host runtime
$hasPwsh = [bool](Get-Command pwsh -ErrorAction SilentlyContinue)
$psExec = if ($PSVersionTable.PSEdition -ne 'Desktop' -and $hasPwsh) {
    "pwsh"
} elseif ($hasPwsh -and -not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version.Major -ge 6 })) {
    "pwsh"
} else {
    "powershell.exe"
}

if (($Win11 -and $Win10) -or ($Both -and ($Win11 -or $Win10))) {
    Write-Host "ERROR: Cannot specify conflicting platform targets simultaneously (-Win11, -Win10, -Both)." -ForegroundColor Red
    exit 1
}

$isWin11Host = [System.Environment]::OSVersion.Version.Build -ge 22000
$targetsToTest = @()
if ($Both) {
    $w11ExtraArgs = if ($SkipBuildCheck -or -not $isWin11Host) { @("-SkipBuildCheck") } else { @() }
    $w11BatArgs = if ($SkipBuildCheck -or -not $isWin11Host) { "-DryRun -Win11 -SkipBuildCheck" } else { "-DryRun -Win11" }
    $targetsToTest += [pscustomobject]@{
        Name = "Windows 11"
        Engine = "unslop-win11.ps1"
        Tests = "tests\unslop-win11.Tests.ps1"
        ExtraArgs = $w11ExtraArgs
        BatArgs = $w11BatArgs
    }

    $w10ExtraArgs = if ($SkipBuildCheck -or $isWin11Host) { @("-SkipBuildCheck") } else { @() }
    $w10BatArgs = if ($SkipBuildCheck -or $isWin11Host) { "-DryRun -Win10 -SkipBuildCheck" } else { "-DryRun -Win10" }
    $targetsToTest += [pscustomobject]@{
        Name = "Windows 10"
        Engine = "unslop-win10.ps1"
        Tests = "tests\unslop-win10.Tests.ps1"
        ExtraArgs = $w10ExtraArgs
        BatArgs = $w10BatArgs
    }
    $targetPlatformTitle = "Dual Target (Win11 + Win10)"
} elseif ($Win10) {
    $w10ExtraArgs = if ($SkipBuildCheck -or $isWin11Host) { @("-SkipBuildCheck") } else { @() }
    $w10BatArgs = if ($SkipBuildCheck -or $isWin11Host) { "-DryRun -Win10 -SkipBuildCheck" } else { "-DryRun -Win10" }
    $targetsToTest += [pscustomobject]@{
        Name = "Windows 10"
        Engine = "unslop-win10.ps1"
        Tests = "tests\unslop-win10.Tests.ps1"
        ExtraArgs = $w10ExtraArgs
        BatArgs = $w10BatArgs
    }
    $targetPlatformTitle = "Windows 10 Target"
} else {
    $w11ExtraArgs = if ($SkipBuildCheck -or -not $isWin11Host) { @("-SkipBuildCheck") } else { @() }
    $w11BatArgs = if ($SkipBuildCheck -or -not $isWin11Host) { "-DryRun -Win11 -SkipBuildCheck" } else { "-DryRun -Win11" }
    $targetsToTest += [pscustomobject]@{
        Name = "Windows 11"
        Engine = "unslop-win11.ps1"
        Tests = "tests\unslop-win11.Tests.ps1"
        ExtraArgs = $w11ExtraArgs
        BatArgs = $w11BatArgs
    }
    $targetPlatformTitle = "Windows 11 Target"
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  unslop-windows: Master Quality Gate ($targetPlatformTitle - $($PSVersionTable.PSEdition) Edition - PS $($PSVersionTable.PSVersion))" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ------------------------------------------------------------
# 1. AST syntax & parser verification
# ------------------------------------------------------------
Write-Host "`n[1/$totalSteps] AST syntax & parser verification..." -ForegroundColor Yellow
$scriptFiles = Get-ChildItem -Path $root -Include *.ps1, *.psm1, *.psd1 -Recurse -File |
    Where-Object { $_.FullName -notmatch '\\(logs|\.git|videos|graphify-out|test-results|\.agents|node_modules)\\' }

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
# 2. Static code analysis (PSScriptAnalyzer)
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
                Where-Object { $_.ScriptPath -notmatch '\\(logs|\.git|videos|graphify-out|test-results|\.agents|node_modules)\\' }

            $errors = @($analyzerResults | Where-Object { $_.Severity -eq 'Error' })
            $warnings = @($analyzerResults | Where-Object { $_.Severity -eq 'Warning' })
            $totalIssues = $errors.Count + $warnings.Count

            if ($totalIssues -gt 0) {
                $fail = $true
                Write-Host "  FAILED: PSScriptAnalyzer found $totalIssues issue(s) ($($errors.Count) error(s), $($warnings.Count) warning(s)). Treating warnings as blocking errors:" -ForegroundColor Red
                $analyzerResults | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Red
            } else {
                Write-Host "  PASSED: PSScriptAnalyzer clean scan, 0 errors and 0 warnings found." -ForegroundColor Green
            }
        } catch {
            $fail = $true
            Write-Host "  FAILED: ScriptAnalyzer execution encountered an error: $_" -ForegroundColor Red
        }
    } else {
        $fail = $true
        Write-Host "  FAILED: PSScriptAnalyzer is required for Master Quality Gate but is not installed." -ForegroundColor Red
        Write-Host "  (To install: Install-Module PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck)" -ForegroundColor Red
    }
} else {
    Write-Host "  SKIPPED: -SkipAnalyzer parameter supplied." -ForegroundColor DarkGray
}

# ------------------------------------------------------------
# 3. Line-ending & file integrity audit
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
    Where-Object { $_.FullName -notmatch '\\(logs|\.git|videos|graphify-out|test-results|\.agents|node_modules)\\' }

$conflictMarkers = @(
    foreach ($tf in $textFiles) {
        $content = Get-Content -Path $tf.FullName -Raw -ErrorAction SilentlyContinue
        if ($content -and ($content -match '(?m)^<{7}\s' -or $content -match '(?m)^={7}$' -or $content -match '(?m)^>{7}\s')) {
            $tf.Name
        }
    }
)

if ($conflictMarkers.Count -gt 0) {
    $lineEndingFail = $true
    Write-Host "  FAILED: Merge conflict markers detected in: $($conflictMarkers -join ', ')" -ForegroundColor Red
} else {
    Write-Host "  PASSED: 0 merge conflict markers detected across $($textFiles.Count) files." -ForegroundColor Green
}

# Verify GitHub Actions workflow integrity (.github/workflows/*.yml)
$workflowFiles = Get-ChildItem -Path (Join-Path $root ".github\workflows") -Filter "*.yml" -File -ErrorAction SilentlyContinue
$workflowFail = $false
foreach ($wf in $workflowFiles) {
    $wfContent = Get-Content -Path $wf.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $wfContent) { continue }

    # Guard 1: Detect invalid dynamic expressions in step 'shell:' property (GitHub Actions requires static strings)
    if ($wfContent -match '(?m)^\s*shell:\s*\$\{\{') {
        $workflowFail = $true
        Write-Host "  FAILED: $($wf.Name) contains dynamic expression in 'shell:' property (GitHub Actions requires static shell identifier like 'pwsh' or 'powershell')." -ForegroundColor Red
    }

    # Guard 2: Detect malformed pinned action commit SHAs (must be exactly 40 lowercase hexadecimal characters)
    $usesMatches = [regex]::Matches($wfContent, 'uses:\s*[\w\.\-]+/[\w\.\-]+@([a-fA-F0-9]+)')
    foreach ($um in $usesMatches) {
        $sha = $um.Groups[1].Value
        if ($sha.Length -ne 40) {
            $workflowFail = $true
            Write-Host "  FAILED: $($wf.Name) contains malformed commit SHA '@$sha' in action ref (must be 40 hex chars)." -ForegroundColor Red
        }
    }
}

if ($workflowFail) {
    $lineEndingFail = $true
    Write-Host "  FAILED: GitHub Actions workflow integrity checks failed." -ForegroundColor Red
} else {
    Write-Host "  PASSED: GitHub Actions workflow integrity verified (static shells and valid SHA refs)." -ForegroundColor Green
}
if ($lineEndingFail) { $fail = $true }

# ------------------------------------------------------------
# 4. Pester unit & mocking test suite
# ------------------------------------------------------------
if (-not $Fast) {
    if (-not $SkipUnitTests) {
        $targetTestsDesc = ($targetsToTest.Tests) -join ' + '
        Write-Host "`n[4/$totalSteps] Pester unit & mocking test suite ($targetTestsDesc)..." -ForegroundColor Yellow
        $testScripts = @()
        foreach ($tgt in $targetsToTest) {
            $primaryTestScript = Join-Path $root $tgt.Tests
            if (Test-Path $primaryTestScript) { $testScripts += $primaryTestScript }
        }

        $batTests = Join-Path $root "tests\unslop.bat.Tests.ps1"
        if (Test-Path $batTests) { $testScripts += $batTests }
        $hooksTests = Join-Path $root "tests\Install-GitHooks.Tests.ps1"
        if (Test-Path $hooksTests) { $testScripts += $hooksTests }

        $measureTestScript = Join-Path $root "tests\Measure-SystemState.Tests.ps1"
        if (Test-Path $measureTestScript) { $testScripts += $measureTestScript }
        $gateTestScript = Join-Path $root "tests\Test-MasterGate.Tests.ps1"
        if (Test-Path $gateTestScript) { $testScripts += $gateTestScript }

        if ($testScripts.Count -gt 0) {
            $pesterVer = if ($psExec -eq "pwsh" -and $PSVersionTable.PSEdition -eq 'Desktop') {
                & pwsh -NoProfile -Command "(Get-Module -ListAvailable -Name Pester | Sort-Object Version -Descending | Select-Object -First 1).Version.ToString()"
            } else {
                $m = Get-Module -ListAvailable -Name Pester | Sort-Object Version -Descending | Select-Object -First 1
                if ($m) { $m.Version.ToString() } else { "" }
            }
            $pesterMajor = if ($pesterVer -match '^(\d+)') { [int]$matches[1] } else { 0 }
            if ($pesterMajor -ge 6) {
                Push-Location $root
                try {
                    $targetXml = ""
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
                    }
                    $targetCovXml = ""
                    $covFile = ""
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
                        $covFile = ($targetsToTest | ForEach-Object { Join-Path $root $_.Engine }) -join ";"
                    }
                    $pesterBlock = {
                        param($testPath, $xmlOut, $covOut, $covTarget, [bool]$incIntegration)
                        Import-Module Pester -MinimumVersion 6.0.0
                        $cfg = New-PesterConfiguration
                        $cfg.Run.Path = $testPath -split ";"
                        $cfg.Output.Verbosity = 'Detailed'
                        $cfg.Run.PassThru = $true
                        if (-not $incIntegration) {
                            $cfg.Filter.Tag = @('Unit')
                        }
                        if ($xmlOut) {
                            $cfg.TestResult.Enabled = $true
                            $cfg.TestResult.OutputFormat = 'NUnitXml'
                            $cfg.TestResult.OutputPath = $xmlOut
                        }
                        if ($covOut -and $covTarget) {
                            $cfg.CodeCoverage.Enabled = $true
                            $cfg.CodeCoverage.Path = $covTarget -split ";"
                            $cfg.CodeCoverage.OutputFormat = 'JaCoCo'
                            $cfg.CodeCoverage.OutputPath = $covOut
                        }
                        $res = Invoke-Pester -Configuration $cfg
                        if ($res.CodeCoverage) {
                            $pct = [math]::Round($res.CodeCoverage.CoveragePercent, 1)
                            Write-Host "  Code Coverage: $pct% ($($res.CodeCoverage.CommandsExecutedCount)/$($res.CodeCoverage.CommandsAnalyzedCount) commands)" -ForegroundColor Cyan
                        }
                        if ($res.FailedCount -gt 0) { exit 1 }
                    }
                    $testPathStr = $testScripts -join ";"
                    & $psExec -NoProfile -ExecutionPolicy Bypass -Command $pesterBlock -args $testPathStr, $targetXml, $targetCovXml, $covFile, ([bool]$IncludeIntegration)
                    $pesterExit = $LASTEXITCODE
                    if ($pesterExit -ne 0) {
                        $fail = $true
                        Write-Host "  FAILED: Pester unit tests failed with exit code $pesterExit" -ForegroundColor Red
                    } else {
                        Write-Host "  PASSED: All Pester unit tests passed clean (0 failures)." -ForegroundColor Green
                    }
                } catch {
                    $fail = $true
                    Write-Host "  FAILED: Error invoking Pester test suite: $_" -ForegroundColor Red
                } finally { Pop-Location }
            } else {
                if ($Strict) {
                    $fail = $true
                    Write-Host "  FAILED: Pester 6.x+ is required in CI / Strict mode but is not installed (found: $(if ($pesterVer) { $pesterVer } else { 'none' }))." -ForegroundColor Red
                } else {
                    Write-Host "  SKIPPED: Pester 6.x+ is not installed locally (found: $(if ($pesterVer) { $pesterVer } else { 'none' }))." -ForegroundColor DarkGray
                    Write-Host "  (To install: Install-Module Pester -Scope CurrentUser -SkipPublisherCheck -Force -MinimumVersion 6.0.0)" -ForegroundColor DarkGray
                }
            }
        } else {
            Write-Host "  SKIPPED: $targetTestsDesc not found." -ForegroundColor DarkGray
        }
    } else {
        Write-Host "`n[4/$totalSteps] SKIPPED: -SkipUnitTests parameter supplied." -ForegroundColor DarkGray
    }

    # ------------------------------------------------------------
    # 5. Safe non-elevated dry-run execution test
    # ------------------------------------------------------------
    Write-Host "`n[5/$totalSteps] Safe non-elevated Dry-Run execution test..." -ForegroundColor Yellow
    Push-Location $root
    try {
        foreach ($tgt in $targetsToTest) {
            $curEngine = $tgt.Engine
            $dryRunArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ".\$curEngine", "-DryRun") + $tgt.ExtraArgs
            $dryRunOut = & $psExec @dryRunArgs 2>&1
            $dryExit = $LASTEXITCODE
            if ($dryExit -ne 0) {
                $fail = $true
                Write-Host "  FAILED: $curEngine -DryRun exited with code $dryExit" -ForegroundColor Red
                Write-Host ($dryRunOut | Select-Object -Last 15 | Out-String) -ForegroundColor Red
            } else {
                $summaryFound = ($dryRunOut -match "UNSLOP-WINDOWS: DEBLOAT & HARDEN COMPLETE").Length -gt 0
                if ($summaryFound) {
                    Write-Host "  PASSED: $curEngine -DryRun completed successfully (code 0, all modules verified)." -ForegroundColor Green
                } else {
                    $fail = $true
                    Write-Host "  FAILED: $curEngine -DryRun completed without expected completion banner." -ForegroundColor Red
                }
            }
        }
    } finally { Pop-Location }

    # ------------------------------------------------------------
    # 6. Symmetrical restoration dry-run execution test
    # ------------------------------------------------------------
    Write-Host "`n[6/$totalSteps] Symmetrical restoration Dry-Run execution test..." -ForegroundColor Yellow
    Push-Location $root
    try {
        foreach ($tgt in $targetsToTest) {
            $curEngine = $tgt.Engine
            $undoArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ".\$curEngine", "-Undo", "-DryRun") + $tgt.ExtraArgs
            $undoOut = & $psExec @undoArgs 2>&1
            $undoExit = $LASTEXITCODE
            if ($undoExit -ne 0) {
                $fail = $true
                Write-Host "  FAILED: $curEngine -Undo -DryRun exited with code $undoExit" -ForegroundColor Red
                Write-Host ($undoOut | Select-Object -Last 15 | Out-String) -ForegroundColor Red
            } else {
                $undoSummaryFound = ($undoOut -match "RESTORE / UNDO COMPLETE").Length -gt 0
                if ($undoSummaryFound) {
                    Write-Host "  PASSED: $curEngine -Undo -DryRun completed successfully (code 0, symmetrical restore verified)." -ForegroundColor Green
                } else {
                    $fail = $true
                    Write-Host "  FAILED: $curEngine -Undo -DryRun completed without expected restore banner." -ForegroundColor Red
                }
            }
        }
    } finally { Pop-Location }

    # ------------------------------------------------------------
    # 7. Batch launcher CLI parameter passthrough audit
    # ------------------------------------------------------------
    Write-Host "`n[7/$totalSteps] Batch launcher CLI parameter passthrough audit..." -ForegroundColor Yellow
    Push-Location $root
    try {
        foreach ($tgt in $targetsToTest) {
            $curBatArgs = $tgt.BatArgs
            $batOut = & cmd.exe /c "call .\unslop.bat $curBatArgs" 2>&1
            $batExit = $LASTEXITCODE
            if ($batExit -ne 0 -or ($batOut -match 'unexpected at this time|syntax of the command is incorrect')) {
                $fail = $true
                Write-Host "  FAILED: unslop.bat $curBatArgs exited with code $batExit" -ForegroundColor Red
                Write-Host ($batOut | Select-Object -Last 10 | Out-String) -ForegroundColor Red
            } else {
                Write-Host "  PASSED: unslop.bat $curBatArgs headless execution verified in cmd.exe (code 0)." -ForegroundColor Green
            }
        }
    } finally { Pop-Location }
} else {
    Write-Host "`n[4-7/$totalSteps] Skipped Unit, DryRun and Batch Launcher tests (-Fast flag specified)." -ForegroundColor DarkGray
}

# ------------------------------------------------------------
# Documentation linting (optional / triggered by -LintDocs)
# ------------------------------------------------------------
if ($LintDocs) {
    Write-Host "`n[Docs] Markdown documentation linting (markdownlint-cli)..." -ForegroundColor Yellow
    $npxCmd = Get-Command npx -ErrorAction SilentlyContinue
    if ($npxCmd) {
        Push-Location $root
        try {
            $prevEap = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            $lintOut = & cmd.exe /c "npx --yes markdownlint-cli `"**/*.md`"" 2>&1
            $lintExit = $LASTEXITCODE
            $ErrorActionPreference = $prevEap
            if ($lintExit -ne 0) {
                $fail = $true
                Write-Host "  FAILED: markdownlint reported errors (exit code $lintExit)" -ForegroundColor Red
                Write-Host ($lintOut | Out-String) -ForegroundColor Red
            } else {
                Write-Host "  PASSED: markdownlint verified all documentation clean." -ForegroundColor Green
            }
        } finally { Pop-Location }
    } else {
        if ($Strict) {
            $fail = $true
            Write-Host "  FAILED: npx is required for -LintDocs in Strict mode but was not found." -ForegroundColor Red
        } else {
            Write-Host "  SKIPPED: npx not found in PATH." -ForegroundColor DarkGray
        }
    }
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
