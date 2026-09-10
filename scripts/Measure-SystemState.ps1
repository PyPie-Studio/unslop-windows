#requires -Version 5.1
<#
.SYNOPSIS
    Standalone system state auditor and diagnostic benchmarking tool for unslop-windows.
    Measures RAM usage, commit charge, process/thread counts, telemetry services, and AppX footprint.

.PARAMETER Snapshot
    Saves the current metrics snapshot to a JSON file in the logs directory or specified path.

.PARAMETER Compare
    Compares two JSON snapshot files and outputs a comparative delta report.
    Example: -Compare ".\logs\before.json", ".\logs\after.json"

.PARAMETER ExportMarkdown
    Exports the benchmark comparison or current state report to a Markdown file.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts/Measure-SystemState.ps1
    powershell -ExecutionPolicy Bypass -File scripts/Measure-SystemState.ps1 -Snapshot "before"
    powershell -ExecutionPolicy Bypass -File scripts/Measure-SystemState.ps1 -Snapshot "after"
    powershell -ExecutionPolicy Bypass -File scripts/Measure-SystemState.ps1 -Compare "logs/before.json", "logs/after.json" -ExportMarkdown "docs/benchmarks.md"
#>
[CmdletBinding(DefaultParameterSetName="Measure")]
param(
    [Parameter(ParameterSetName="Snapshot")]
    [string]$Snapshot,

    [Parameter(ParameterSetName="Compare")]
    [string[]]$Compare,

    [Parameter(ParameterSetName="Compare")]
    [string]$Baseline,

    [Parameter(ParameterSetName="Compare")]
    [string]$Target,

    [Parameter(ParameterSetName="Compare")]
    [string]$ExportMarkdown
)

$ErrorActionPreference = "SilentlyContinue"
$root = Split-Path -Parent $PSScriptRoot

# Normalize CLI parameter values
if ($Snapshot) {
    $Snapshot = $Snapshot.Trim(" `"`',`r`n")
}
if ($Compare) {
    $cleanCompare = @()
    foreach ($item in $Compare) {
        $parts = $item.Split(',') | ForEach-Object { $_.Trim(" `"`',`r`n") } | Where-Object { $_ }
        $cleanCompare += $parts
    }
    $Compare = $cleanCompare
}
if ($Baseline) { $Baseline = $Baseline.Trim(" `"`',`r`n") }
if ($Target)   { $Target   = $Target.Trim(" `"`',`r`n") }

function Get-SystemMetrics {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue

    $totalRamBytes = $os.TotalVisibleMemorySize * 1KB
    $freeRamBytes  = $os.FreePhysicalMemory * 1KB
    $usedRamBytes  = $totalRamBytes - $freeRamBytes

    $totalCommitBytes = $os.TotalVirtualMemorySize * 1KB
    $freeCommitBytes  = $os.FreeVirtualMemory * 1KB
    $usedCommitBytes  = $totalCommitBytes - $freeCommitBytes

    $processes = Get-Process -ErrorAction SilentlyContinue
    $processCount = if ($processes) { $processes.Count } else { 0 }
    $threadCount = 0
    if ($processes) {
        # Performance Optimization: Fast direct iteration over processes (avoids pipeline allocation overhead)
        foreach ($proc in $processes) {
            $threadCount += $proc.Threads.Count
        }
    }

    # Telemetry services audit
    $targetServices = @("DiagTrack", "dmwappushservice", "diagnosticshub.standardcollector.service", "SysMain", "WSearch")
    $servicesData = @{}
    foreach ($svcName in $targetServices) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        $servicesData[$svcName] = if ($svc) { $svc.Status.ToString() } else { "NotFound" }
    }

    # Telemetry scheduled tasks audit
    $targetTasks = @(
        @{ Name = "Consolidator"; Path = "\Microsoft\Windows\Customer Experience Improvement Program\" },
        @{ Name = "UsbCeip"; Path = "\Microsoft\Windows\Customer Experience Improvement Program\" },
        @{ Name = "Microsoft Compatibility Appraiser"; Path = "\Microsoft\Windows\Application Experience\" },
        @{ Name = "ProgramDataUpdater"; Path = "\Microsoft\Windows\Application Experience\" }
    )
    $tasksData = @{}
    foreach ($t in $targetTasks) {
        $taskObj = Get-ScheduledTask -TaskName $t.Name -TaskPath $t.Path -ErrorAction SilentlyContinue
        $tasksData[$t.Name] = if ($taskObj) { $taskObj.State.ToString() } else { "NotFound" }
    }

    # AppX packages audit
    $appxUserPackages = Get-AppxPackage -ErrorAction SilentlyContinue
    $appxUserCount = if ($appxUserPackages) { $appxUserPackages.Count } else { 0 }

    $appxProvisionedCount = "Unavailable (requires elevation)"
    try {
        $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
        if ($provisioned) { $appxProvisionedCount = $provisioned.Count }
    } catch {}

    [PSCustomObject]@{
        Timestamp          = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        OSVersion          = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).DisplayVersion
        OSBuild            = [System.Environment]::OSVersion.Version.ToString()
        TotalRAM_GB        = [math]::Round($totalRamBytes / 1GB, 2)
        UsedRAM_GB         = [math]::Round($usedRamBytes / 1GB, 2)
        FreeRAM_GB         = [math]::Round($freeRamBytes / 1GB, 2)
        UsedRAM_Percent    = [math]::Round(($usedRamBytes / $totalRamBytes) * 100, 1)
        CommitUsed_GB      = [math]::Round($usedCommitBytes / 1GB, 2)
        CommitLimit_GB     = [math]::Round($totalCommitBytes / 1GB, 2)
        ProcessCount       = $processCount
        ThreadCount        = $threadCount
        Services           = $servicesData
        ScheduledTasks     = $tasksData
        AppxUserPackages   = $appxUserCount
        AppxProvisioned    = $appxProvisionedCount
    }
}

# -----------------------------------------------------------------------------
# Snapshot Comparison Handler
# -----------------------------------------------------------------------------
$isCompare = ($Compare -and $Compare.Count -ge 2) -or ($Baseline -and $Target)
if ($isCompare) {
    $path1 = if ($Baseline) { $Baseline } else { $Compare[0] }
    $path2 = if ($Target) { $Target } else { $Compare[1] }

    if (-not (Test-Path $path1)) { Write-Error "Snapshot 1 not found at: $path1"; exit 1 }
    if (-not (Test-Path $path2)) { Write-Error "Snapshot 2 not found at: $path2"; exit 1 }

    $s1 = Get-Content -Path $path1 -Raw | ConvertFrom-Json
    $s2 = Get-Content -Path $path2 -Raw | ConvertFrom-Json

    $ramDelta = [math]::Round($s2.UsedRAM_GB - $s1.UsedRAM_GB, 2)
    $ramPctDelta = [math]::Round($s2.UsedRAM_Percent - $s1.UsedRAM_Percent, 1)
    $commitDelta = [math]::Round($s2.CommitUsed_GB - $s1.CommitUsed_GB, 2)
    $procDelta = $s2.ProcessCount - $s1.ProcessCount
    $threadDelta = $s2.ThreadCount - $s1.ThreadCount
    $appxDelta = $s2.AppxUserPackages - $s1.AppxUserPackages

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  unslop-windows: Benchmark Comparison" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "Baseline (Before): $($s1.Timestamp) (Build $($s1.OSBuild))" -ForegroundColor DarkGray
    Write-Host "Debloated (After): $($s2.Timestamp) (Build $($s2.OSBuild))`n" -ForegroundColor DarkGray

    $tableData = @(
        [PSCustomObject]@{ Metric = "Used RAM (GB)"; Before = $s1.UsedRAM_GB; After = $s2.UsedRAM_GB; Delta = "$ramDelta GB" },
        [PSCustomObject]@{ Metric = "Used RAM (%)"; Before = "$($s1.UsedRAM_Percent)%"; After = "$($s2.UsedRAM_Percent)%"; Delta = "$ramPctDelta%" },
        [PSCustomObject]@{ Metric = "Commit Charge (GB)"; Before = $s1.CommitUsed_GB; After = $s2.CommitUsed_GB; Delta = "$commitDelta GB" },
        [PSCustomObject]@{ Metric = "Active Processes"; Before = $s1.ProcessCount; After = $s2.ProcessCount; Delta = $procDelta },
        [PSCustomObject]@{ Metric = "Active Threads"; Before = $s1.ThreadCount; After = $s2.ThreadCount; Delta = $threadDelta },
        [PSCustomObject]@{ Metric = "Installed AppX Packages"; Before = $s1.AppxUserPackages; After = $s2.AppxUserPackages; Delta = $appxDelta }
    )
    $tableData | Format-Table -AutoSize

    Write-Host "`nTelemetry Services Delta:" -ForegroundColor Yellow
    foreach ($svcKey in $s1.Services.PSObject.Properties.Name) {
        $beforeVal = $s1.Services.$svcKey
        $afterVal  = $s2.Services.$svcKey
        $statusColor = if ($afterVal -eq "Stopped" -or $afterVal -eq "NotFound") { "Green" } else { "Yellow" }
        Write-Host "  $svcKey : $beforeVal -> $afterVal" -ForegroundColor $statusColor
    }

    if ($ExportMarkdown) {
        $mdLines = @(
            "# unslop-windows System State Benchmark Report",
            "",
            "Comparative audit report measuring baseline system footprint versus post-hardening optimization.",
            "",
            "- **Benchmark Date:** $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))",
            "- **OS Version:** Windows 11 $($s2.OSVersion) (Build $($s2.OSBuild))",
            "- **Baseline Snapshot:** ``$path1`` ($($s1.Timestamp))",
            "- **Debloated Snapshot:** ``$path2`` ($($s2.Timestamp))",
            "",
            "## Resource Utilization Metrics",
            "",
            "| Metric | Baseline | Post-Hardening | Delta / Reduction |",
            "| :--- | :--- | :--- | :--- |",
            "| **Used RAM** | $($s1.UsedRAM_GB) GB ($($s1.UsedRAM_Percent)%) | $($s2.UsedRAM_GB) GB ($($s2.UsedRAM_Percent)%) | **$ramDelta GB** ($ramPctDelta%) |",
            "| **Commit Charge** | $($s1.CommitUsed_GB) GB | $($s2.CommitUsed_GB) GB | **$commitDelta GB** |",
            "| **Active Processes** | $($s1.ProcessCount) | $($s2.ProcessCount) | **$procDelta** |",
            "| **Active Threads** | $($s1.ThreadCount) | $($s2.ThreadCount) | **$threadDelta** |",
            "| **User AppX Packages** | $($s1.AppxUserPackages) | $($s2.AppxUserPackages) | **$appxDelta** |",
            "",
            "## Telemetry Services State",
            "",
            "| Service Name | Baseline State | Hardened State |",
            "| :--- | :--- | :--- |"
        )
        foreach ($svcKey in $s1.Services.PSObject.Properties.Name) {
            $mdLines += "| ``$svcKey`` | $($s1.Services.$svcKey) | $($s2.Services.$svcKey) |"
        }
        $mdLines += @(
            "",
            "---",
            "*Report generated automatically by ``scripts/Measure-SystemState.ps1`` - [unslop-windows](https://github.com/PyPie-Studio/unslop-windows)*"
        )
        $mdContent = $mdLines -join "`n"
        $targetPath = if ([System.IO.Path]::IsPathRooted($ExportMarkdown)) { $ExportMarkdown } else { Join-Path $root $ExportMarkdown }
        $mdDir = Split-Path -Parent $targetPath
        if (-not (Test-Path $mdDir)) {
            New-Item -Path $mdDir -ItemType Directory -Force | Out-Null
        } else {
            $dirItem = Get-Item -Path $mdDir -ErrorAction SilentlyContinue
            if ($dirItem -and ($dirItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                Write-Error "[SECURITY ERROR] Target directory '$mdDir' is a reparse point or junction. Aborting export to prevent symlink redirection."
                exit 1
            }
        }
        [System.IO.File]::WriteAllText($targetPath, $mdContent, [System.Text.UTF8Encoding]::new($false))
        Write-Host "`nExported Markdown report to: $targetPath" -ForegroundColor Green
    }
    exit 0
}

# -----------------------------------------------------------------------------
# Live Metrics Measurement & Single Snapshot Handler
# -----------------------------------------------------------------------------
$metrics = Get-SystemMetrics

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  unslop-windows: System State Auditor" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Time: $($metrics.Timestamp) | Windows 11 $($metrics.OSVersion) (Build $($metrics.OSBuild))`n" -ForegroundColor DarkGray

Write-Host "[Memory & Commit Charge]" -ForegroundColor Yellow
Write-Host "  Total RAM:    $($metrics.TotalRAM_GB) GB"
Write-Host "  Used RAM:     $($metrics.UsedRAM_GB) GB ($($metrics.UsedRAM_Percent)%)"
Write-Host "  Free RAM:     $($metrics.FreeRAM_GB) GB"
Write-Host "  Commit Used:  $($metrics.CommitUsed_GB) GB / $($metrics.CommitLimit_GB) GB"

Write-Host "`n[Processes & Execution]" -ForegroundColor Yellow
Write-Host "  Processes:    $($metrics.ProcessCount)"
Write-Host "  Threads:      $($metrics.ThreadCount)"

Write-Host "`n[AppX Packages]" -ForegroundColor Yellow
Write-Host "  User Packages:       $($metrics.AppxUserPackages)"
Write-Host "  Provisioned Packages: $($metrics.AppxProvisioned)"

Write-Host "`n[Telemetry Services]" -ForegroundColor Yellow
foreach ($svcKey in $metrics.Services.Keys) {
    $val = $metrics.Services[$svcKey]
    $color = if ($val -eq "Running") { "Yellow" } else { "Green" }
    Write-Host "  $($svcKey.PadRight(38)): $val" -ForegroundColor $color
}

Write-Host "`n[Scheduled Tasks]" -ForegroundColor Yellow
foreach ($taskKey in $metrics.ScheduledTasks.Keys) {
    $val = $metrics.ScheduledTasks[$taskKey]
    $color = if ($val -eq "Ready") { "Yellow" } else { "Green" }
    Write-Host "  $($taskKey.PadRight(38)): $val" -ForegroundColor $color
}

# Save snapshot if requested
if ($Snapshot) {
    $fileName = if ($Snapshot.EndsWith(".json")) { $Snapshot } else { "$Snapshot.json" }
    $snapshotPath = if ([System.IO.Path]::IsPathRooted($fileName)) { $fileName } else { Join-Path (Join-Path $root "logs") $fileName }
    $snapshotDir = Split-Path -Parent $snapshotPath

    if (-not (Test-Path $snapshotDir)) {
        New-Item -Path $snapshotDir -ItemType Directory -Force | Out-Null
    } else {
        $dirItem = Get-Item -Path $snapshotDir -ErrorAction SilentlyContinue
        if ($dirItem -and ($dirItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
            Write-Error "[SECURITY ERROR] Target snapshot directory '$snapshotDir' is a reparse point or junction. Aborting snapshot export to prevent symlink redirection."
            exit 1
        }
    }

    $metricsJson = $metrics | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($snapshotPath, $metricsJson, [System.Text.UTF8Encoding]::new($false))
    Write-Host "`nSaved snapshot to: $snapshotPath" -ForegroundColor Green
}

exit 0
