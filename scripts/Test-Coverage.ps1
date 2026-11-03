#requires -Version 5.1
<#
.SYNOPSIS
    Runs test suites with Pester code coverage, aggregates multi-script metrics,
    displays formatted console tables, and generates Markdown coverage reports.

.DESCRIPTION
    Executes Pester 6+ unit test suites with code coverage enabled across core
    engines (unslop-win11.ps1 / unslop-win10.ps1) and developer utility scripts
    (Measure-SystemState.ps1, Install-GitHooks.ps1, Test-MasterGate.ps1, Test-Coverage.ps1).
    Outputs a structured terminal table and optionally updates docs/coverage-report.md.

.PARAMETER Detailed
    When specified, outputs individual missed command blocks and line numbers.

.PARAMETER ReportPath
    Path where the Markdown coverage report should be written (defaults to docs/coverage-report.md).

.PARAMETER NoMarkdown
    When specified, suppresses writing the Markdown report file.

.PARAMETER Threshold
    Optional minimum total command coverage percentage (0.0 to 100.0). Exits with code 1 if total coverage falls below threshold.

.PARAMETER Win11
    Profiles Windows 11 debloat engine and support scripts (default).

.PARAMETER Win10
    Profiles Windows 10 debloat engine and support scripts.

.PARAMETER Both
    Profiles both Windows 11 and Windows 10 debloat engines simultaneously.

.PARAMETER SkipTest
    When specified, reuses existing test results rather than executing Pester.

.PARAMETER CoverageResultsPath
    Optional file path to export JaCoCo XML coverage metrics.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts/Test-Coverage.ps1
    powershell -ExecutionPolicy Bypass -File scripts/Test-Coverage.ps1 -Detailed
    powershell -ExecutionPolicy Bypass -File scripts/Test-Coverage.ps1 -Threshold 15.0
    powershell -ExecutionPolicy Bypass -File scripts/Test-Coverage.ps1 -Both
#>
[CmdletBinding()]
param(
    [switch]$Detailed,
    [string]$ReportPath = "docs/coverage-report.md",
    [switch]$NoMarkdown,
    [ValidateRange(0.0, 100.0)]
    [double]$Threshold = 0.0,
    [switch]$Win11,
    [switch]$Win10,
    [switch]$Both,
    [switch]$SkipTest,
    [string]$CoverageResultsPath
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

if (($Win11 -and $Win10) -or ($Both -and ($Win11 -or $Win10))) {
    Write-Host "ERROR: Cannot specify conflicting platform targets simultaneously (-Win11, -Win10, -Both)." -ForegroundColor Red
    exit 1
}

# Resolve target engines and title
$targetEngines = @()
if ($Both) {
    $targetEngines += "unslop-win11.ps1"
    $targetEngines += "unslop-win10.ps1"
    $platformTitle = "Dual Target (Win11 + Win10)"
} elseif ($Win10) {
    $targetEngines += "unslop-win10.ps1"
    $platformTitle = "Windows 10 Target"
} else {
    $targetEngines += "unslop-win11.ps1"
    $platformTitle = "Windows 11 Target"
}

# Resolve support utility scripts
$supportScripts = @(
    "scripts\Measure-SystemState.ps1",
    "scripts\Install-GitHooks.ps1",
    "scripts\Test-MasterGate.ps1",
    "scripts\Test-Coverage.ps1"
)

# Build full target coverage list
$coverageTargetFiles = @()
foreach ($eng in $targetEngines) {
    $engPath = Join-Path $root $eng
    if (Test-Path -LiteralPath $engPath) { $coverageTargetFiles += $engPath }
}
foreach ($sub in $supportScripts) {
    $subPath = Join-Path $root $sub
    if (Test-Path -LiteralPath $subPath) { $coverageTargetFiles += $subPath }
}

# Resolve test suites to execute
$testSuiteFiles = @()
if ($targetEngines -contains "unslop-win11.ps1") {
    $w11Test = Join-Path $root "tests\unslop-win11.Tests.ps1"
    if (Test-Path -LiteralPath $w11Test) { $testSuiteFiles += $w11Test }
}
if ($targetEngines -contains "unslop-win10.ps1") {
    $w10Test = Join-Path $root "tests\unslop-win10.Tests.ps1"
    if (Test-Path -LiteralPath $w10Test) { $testSuiteFiles += $w10Test }
}

$commonTests = @(
    "tests\unslop.bat.Tests.ps1",
    "tests\Install-GitHooks.Tests.ps1",
    "tests\Measure-SystemState.Tests.ps1",
    "tests\Test-MasterGate.Tests.ps1",
    "tests\Test-Coverage.Tests.ps1"
)
foreach ($ct in $commonTests) {
    $ctPath = Join-Path $root $ct
    if (Test-Path -LiteralPath $ctPath) { $testSuiteFiles += $ctPath }
}

Write-Host "========================================================================================" -ForegroundColor Cyan
Write-Host "                   unslop-windows: Code Coverage & Telemetry Diagnostic                " -ForegroundColor Cyan
Write-Host "========================================================================================" -ForegroundColor Cyan
Write-Host "  Platform : $platformTitle" -ForegroundColor DarkGray
Write-Host "  Targets  : $($coverageTargetFiles.Count) scripts monitored" -ForegroundColor DarkGray
Write-Host "  Suites   : $($testSuiteFiles.Count) test suites registered`n" -ForegroundColor DarkGray

# Check Pester availability
$hasPwsh = [bool](Get-Command pwsh -ErrorAction SilentlyContinue)
$psExec = if ($PSVersionTable.PSEdition -ne 'Desktop' -and $hasPwsh) {
    "pwsh"
} elseif ($hasPwsh -and -not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version.Major -ge 6 })) {
    "pwsh"
} else {
    "powershell.exe"
}

$pesterVer = if ($psExec -eq "pwsh" -and $PSVersionTable.PSEdition -eq 'Desktop') {
    & pwsh -NoProfile -Command "(Get-Module -ListAvailable -Name Pester | Sort-Object Version -Descending | Select-Object -First 1).Version.ToString()"
} else {
    $m = Get-Module -ListAvailable -Name Pester | Sort-Object Version -Descending | Select-Object -First 1
    if ($m) { $m.Version.ToString() } else { "" }
}
$pesterMajor = if ($pesterVer -match '^(\d+)') { [int]$matches[1] } else { 0 }

if ($pesterMajor -lt 6) {
    Write-Host "ERROR: Pester 6.0.0+ is required for code coverage telemetry (found: $(if ($pesterVer) { $pesterVer } else { 'none' }))." -ForegroundColor Red
    Write-Host "Install via: Install-Module -Name Pester -Scope CurrentUser -Force -MinimumVersion 6.0.0" -ForegroundColor DarkGray
    exit 1
}

$targetCovXml = ""
if ($CoverageResultsPath) {
    $targetCovXml = if ([System.IO.Path]::IsPathRooted($CoverageResultsPath)) {
        $CoverageResultsPath
    } else {
        Join-Path $root $CoverageResultsPath
    }
    $covDir = Split-Path -Parent $targetCovXml
    if ($covDir -and -not (Test-Path -LiteralPath $covDir)) {
        New-Item -ItemType Directory -Path $covDir -Force | Out-Null
    }
}

$testPathStr = $testSuiteFiles -join ";"
$covTargetStr = $coverageTargetFiles -join ";"

$tempJsonPath = [System.IO.Path]::GetTempFileName()

$covData = $null
try {
    $pesterRunner = {
        param($testPath, $covTarget, $covXmlOut, $jsonOutPath)
        Import-Module Pester -MinimumVersion 6.0.0
        $cfg = New-PesterConfiguration
        $cfg.Run.Path = $testPath -split ";"
        $cfg.Filter.Tag = @('Unit')
        $cfg.Output.Verbosity = 'None'
        $cfg.Run.PassThru = $true
        $cfg.CodeCoverage.Enabled = $true
        $cfg.CodeCoverage.Path = $covTarget -split ";"
        if ($covXmlOut) {
            $cfg.CodeCoverage.OutputFormat = 'JaCoCo'
            $cfg.CodeCoverage.OutputPath = $covXmlOut
        }
        $res = Invoke-Pester -Configuration $cfg

        $executedByFile = $res.CodeCoverage.CommandsExecuted | Group-Object File -AsHashTable -AsString
        $missedByFile = $res.CodeCoverage.CommandsMissed | Group-Object File -AsHashTable -AsString

        $filesData = @()
        foreach ($f in $res.CodeCoverage.FilesAnalyzed) {
            $ex = if ($executedByFile.ContainsKey($f)) { $executedByFile[$f].Count } else { 0 }
            $ms = if ($missedByFile.ContainsKey($f)) { $missedByFile[$f].Count } else { 0 }
            $tot = $ex + $ms
            $pct = if ($tot -gt 0) { [math]::Round(100.0 * $ex / $tot, 1) } else { 0.0 }
            
            $missedList = @()
            if ($missedByFile.ContainsKey($f)) {
                $missedList = $missedByFile[$f] | ForEach-Object {
                    [pscustomobject]@{
                        Line = $_.Line
                        Command = $_.Command
                        Function = $_.Function
                    }
                }
            }

            $filesData += [pscustomobject]@{
                FilePath = $f
                FileName = Split-Path -Leaf $f
                Executed = $ex
                Missed   = $ms
                Total    = $tot
                Percent  = $pct
                MissedCommands = $missedList
            }
        }

        $summary = [pscustomobject]@{
            TotalExecuted = $res.CodeCoverage.CommandsExecutedCount
            TotalMissed   = $res.CodeCoverage.CommandsMissedCount
            TotalCommands = $res.CodeCoverage.CommandsAnalyzedCount
            TotalPercent  = [math]::Round($res.CodeCoverage.CoveragePercent, 1)
            TestCount     = $res.TotalCount
            PassedCount   = $res.PassedCount
            FailedCount   = $res.FailedCount
            Files         = $filesData
        }

        $jsonStr = $summary | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($jsonOutPath, $jsonStr, [System.Text.Encoding]::UTF8)
    }

    Write-Host "Running Pester unit test suites and profiling code coverage..." -ForegroundColor Yellow
    & $psExec -NoProfile -ExecutionPolicy Bypass -Command $pesterRunner -args $testPathStr, $covTargetStr, $targetCovXml, $tempJsonPath

    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $tempJsonPath) -or ((Get-Item -LiteralPath $tempJsonPath).Length -eq 0)) {
        Write-Host "ERROR: Code coverage execution failed." -ForegroundColor Red
        exit 1
    }

    $rawJson = [System.IO.File]::ReadAllText($tempJsonPath, [System.Text.Encoding]::UTF8)
    $covData = $rawJson | ConvertFrom-Json
} finally {
    if (Test-Path -LiteralPath $tempJsonPath) {
        Remove-Item -LiteralPath $tempJsonPath -Force -ErrorAction SilentlyContinue
    }
}

# Script role dictionary for UI presentation
$roleMap = @{
    "unslop-win11.ps1"        = "Windows 11 Debloat & Hardening Engine"
    "unslop-win10.ps1"        = "Windows 10 Debloat & Hardening Engine"
    "Measure-SystemState.ps1" = "System State & Benchmark Telemetry"
    "Install-GitHooks.ps1"    = "Git Hooks & Environment Setup"
    "Test-MasterGate.ps1"     = "Master Quality Gate & CI Pipeline"
    "Test-Coverage.ps1"       = "Code Coverage Profiler & Reporter"
}

# Render formatted console table
Write-Host "----------------------------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ("{0,-26} {1,-35} {2,12} {3,9}" -f "File", "Role", "Commands", "Coverage") -ForegroundColor Yellow
Write-Host "----------------------------------------------------------------------------------------" -ForegroundColor DarkGray

foreach ($f in $covData.Files) {
    $role = if ($roleMap.ContainsKey($f.FileName)) { $roleMap[$f.FileName] } else { "PowerShell Script" }
    $cmdCol = "$($f.Executed) / $($f.Total)"
    $pctCol = "$($f.Percent) %"
    $rowColor = if ($f.Percent -ge 70.0) { "Green" } elseif ($f.Percent -ge 20.0) { "Cyan" } elseif ($f.Percent -gt 0.0) { "Yellow" } else { "DarkGray" }
    Write-Host ("{0,-26} {1,-35} {2,12} {3,9}" -f $f.FileName, $role, $cmdCol, $pctCol) -ForegroundColor $rowColor
}

Write-Host "----------------------------------------------------------------------------------------" -ForegroundColor DarkGray
$totalCmdCol = "$($covData.TotalExecuted) / $($covData.TotalCommands)"
$totalPctCol = "$($covData.TotalPercent) %"
$totColor = if ($covData.TotalPercent -ge 50.0) { "Green" } elseif ($covData.TotalPercent -ge 15.0) { "Cyan" } else { "Yellow" }
Write-Host ("{0,-26} {1,-35} {2,12} {3,9}" -f "TOTAL", "Codebase Aggregate", $totalCmdCol, $totalPctCol) -ForegroundColor $totColor
Write-Host "========================================================================================`n" -ForegroundColor DarkGray

# If -Detailed, print missed command summaries
if ($Detailed) {
    Write-Host "=== Detailed Missed Commands Breakdown ===" -ForegroundColor Yellow
    foreach ($f in $covData.Files) {
        if ($f.MissedCommands -and $f.MissedCommands.Count -gt 0) {
            Write-Host "`n[$($f.FileName)] - $($f.Missed) unexercised commands:" -ForegroundColor Cyan
            $topMissed = $f.MissedCommands | Select-Object -First 10
            foreach ($m in $topMissed) {
                $fnDesc = if ($m.Function) { " ($($m.Function))" } else { "" }
                Write-Host "  Line $($m.Line.ToString().PadRight(5))$fnDesc : $($m.Command)" -ForegroundColor DarkGray
            }
            if ($f.MissedCommands.Count -gt 10) {
                Write-Host "  ... and $($f.MissedCommands.Count - 10) more commands." -ForegroundColor DarkGray
            }
        }
    }
    Write-Host ""
}

# Generate Markdown Report unless -NoMarkdown
if (-not $NoMarkdown) {
    $resolvedReport = if ([System.IO.Path]::IsPathRooted($ReportPath)) {
        $ReportPath
    } else {
        Join-Path $root $ReportPath
    }
    $reportDir = Split-Path -Parent $resolvedReport
    if ($reportDir -and -not (Test-Path -LiteralPath $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }

    $timestamp = (Get-Date).ToString("yyyy-MM-dd hh:mm tt")

    $mdLines = @()
    $mdLines += "# unslop-windows: Test Coverage & Verification Report"
    $mdLines += ""
    $mdLines += "> Automatically generated by [`scripts/Test-Coverage.ps1`](file:///c:/Users/tryku/Desktop/Coding/Projects/unslop-windows/scripts/Test-Coverage.ps1) on **$timestamp**."
    $mdLines += ""
    $mdLines += "## 1. Summary Metrics"
    $mdLines += ""
    $mdLines += "| Metric | Value |"
    $mdLines += "| :--- | :--- |"
    $mdLines += "| **Platform Target** | $platformTitle |"
    $mdLines += "| **Total Codebase Coverage** | **$($covData.TotalPercent)%** |"
    $mdLines += "| **Commands Executed** | $($covData.TotalExecuted) / $($covData.TotalCommands) |"
    $mdLines += "| **Unit Tests Executed** | $($covData.TestCount) (Passed: $($covData.PassedCount), Failed: $($covData.FailedCount)) |"
    $mdLines += "| **Scripts Monitored** | $($covData.Files.Count) files |"
    $mdLines += ""
    $mdLines += "## 2. Per-Script Coverage Breakdown"
    $mdLines += ""
    $mdLines += "| File | Architectural Role | Executed Commands | Total Commands | Coverage % | Status |"
    $mdLines += "| :--- | :--- | :--- | :--- | :--- | :--- |"

    foreach ($f in $covData.Files) {
        $fName = $f.FileName
        $fileUri = "file:///" + ($f.FilePath -replace '\\', '/')
        $role = if ($roleMap.ContainsKey($fName)) { $roleMap[$fName] } else { "PowerShell Script" }
        $badge = if ($f.Percent -ge 70.0) { "High" } elseif ($f.Percent -ge 20.0) { "Standard" } elseif ($f.Percent -gt 0.0) { "Partial" } else { "Structural" }
        $mdLines += "| [$fName]($fileUri) | $role | $($f.Executed) | $($f.Total) | **$($f.Percent)%** | $badge |"
    }

    $mdLines += "| **TOTAL** | **Codebase Aggregate** | **$($covData.TotalExecuted)** | **$($covData.TotalCommands)** | **$($covData.TotalPercent)%** | **-** |"
    $mdLines += ""
    $mdLines += "## 3. Safe-Tier Verification Methodology"
    $mdLines += ""
    $mdLines += "unslop-windows balances high-rigor test coverage with non-elevated safety across three distinct verification pillars:"
    $mdLines += ""
    $mdLines += '1. **In-Process Unit Testing (`tests/*.Tests.ps1`):**'
    $mdLines += '   - All core helper routines (`Set-RegDwordSafe`, `Remove-RegValueSafe`, `Set-RegStringSafe`, `Set-SvcState`, `Set-TaskState`, `Set-ConsentCapability`, `Remove-StartupEntry`) and utility scripts are dot-sourced and verified under Pester 6+ mocking with near-100% functional coverage.'
    $mdLines += '   - Engines halt at the non-elevated dot-source guard (`if ($MyInvocation.InvocationName -eq ".") { return }`) to prevent inadvertent system state mutations during test execution.'
    $mdLines += ''
    $mdLines += '2. **Abstract Syntax Tree (AST) Parity Audits:**'
    $mdLines += '   - The remaining procedural debloat commands (Modules 1–18) are verified statically by inspecting PowerShell AST tokens.'
    $mdLines += '   - Ensures 100% Symmetrical Restoration (`-Undo`), verifies zero naked mutating cmdlets exist outside approved helpers, and asserts DISM/WinSxS component store inviolability.'
    $mdLines += ''
    $mdLines += '3. **Subprocess Dry-Run Smoke Audits (Master Gate Steps 5, 6, 7):**'
    $mdLines += '   - Full system scans execute end-to-end in safe, non-elevated `-DryRun` mode via external subprocesses (`unslop-win11.ps1 -DryRun`, `-Undo -DryRun`, and `unslop.bat -DryRun`).'
    $mdLines += ""
    $mdLines += "---"
    $mdLines += ""
    $mdLines += "*Document co-evolved per ADR-048 standards.*"

    $mdContent = ($mdLines -join [System.Environment]::NewLine) + [System.Environment]::NewLine
    [System.IO.File]::WriteAllText($resolvedReport, $mdContent, [System.Text.Encoding]::UTF8)
    Write-Host "Generated Markdown coverage report: $resolvedReport" -ForegroundColor Green
}

# Evaluate threshold if specified
if ($Threshold -gt 0) {
    if ($covData.TotalPercent -lt $Threshold) {
        Write-Host "`n[FAIL] Total code coverage ($($covData.TotalPercent)%) is below required threshold ($Threshold%)." -ForegroundColor Red
        exit 1
    } else {
        Write-Host "`n[PASS] Total code coverage ($($covData.TotalPercent)%) meets required threshold ($Threshold%)." -ForegroundColor Green
        exit 0
    }
}

exit 0
