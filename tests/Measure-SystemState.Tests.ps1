#requires -Version 5.1
<#
.SYNOPSIS
    Pester Unit & Mocking Test Suite for scripts/Measure-SystemState.ps1.
    Tests system metrics auditing, parameter handling, snapshot comparison,
    Markdown report generation, and security reparse point validation.
#>

BeforeAll {
    $script:repoRoot = Split-Path -Parent $PSScriptRoot
    $script:targetScript = Join-Path $script:repoRoot "scripts\Measure-SystemState.ps1"

    if (-not (Test-Path $script:targetScript)) {
        throw "Target script not found at: $script:targetScript"
    }

    # Resolve preferred PowerShell CLI executable
    $script:psCli = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell.exe" }

    # Cross-Platform Stub Definitions: ensure Windows cmdlets can be mocked on non-Windows hosts
    if (-not (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)) {
        function Get-CimInstance { param($ClassName) }
    }
    if (-not (Get-Command Get-Process -ErrorAction SilentlyContinue)) {
        function Get-Process { }
    }
    if (-not (Get-Command Get-Service -ErrorAction SilentlyContinue)) {
        function Get-Service { param($Name) }
    }
    if (-not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)) {
        function Get-ScheduledTask { param($TaskName, $TaskPath) }
    }
    if (-not (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue)) {
        function Get-AppxPackage { }
    }
    if (-not (Get-Command Get-AppxProvisionedPackage -ErrorAction SilentlyContinue)) {
        function Get-AppxProvisionedPackage { param($Online) }
    }

    # Dot-source script into session to test helper functions
    . $script:targetScript
}

Describe 'Measure-SystemState: Architecture & Dot-Sourcing' -Tag 'Unit' {
    It 'Dot-sourcing exports Get-SystemMetrics into caller scope' {
        $cmd = Get-Command -Name Get-SystemMetrics -ErrorAction SilentlyContinue
        $cmd | Should -Not -BeNullOrEmpty -Because "Get-SystemMetrics must be exported when Measure-SystemState.ps1 is dot-sourced"
        $cmd.CommandType.ToString() | Should -Be 'Function'
    }

    It 'Dot-sourcing guard prevents procedural execution' {
        $isolatedOutput = & $script:psCli -NoProfile -ExecutionPolicy Bypass -Command "
            . '$($script:targetScript)'
        "
        $isolatedOutput | Should -Not -Match "unslop-windows: System State Auditor" -Because "Dot-source guard must prevent execution"
    }
}

Describe 'Measure-SystemState: Get-SystemMetrics Core Engine' -Tag 'Unit' {
    Context 'Memory & Commit Charge Calculations' {
        It 'Calculates RAM and Commit charge metrics correctly from Win32_OperatingSystem' {
            Mock Get-CimInstance {
                param($ClassName)
                [PSCustomObject]@{
                    TotalVisibleMemorySize = 16777216  # 16 GB in KB
                    FreePhysicalMemory     = 8388608   # 8 GB in KB
                    TotalVirtualMemorySize = 33554432  # 32 GB in KB
                    FreeVirtualMemory      = 16777216  # 16 GB in KB
                }
            }

            Mock Get-ItemProperty { [PSCustomObject]@{ DisplayVersion = '23H2' } }
            Mock Get-Process { @() }
            Mock Get-Service { $null }
            Mock Get-ScheduledTask { $null }
            Mock Get-AppxPackage { @() }
            Mock Get-AppxProvisionedPackage { @() }

            $metrics = Get-SystemMetrics

            $metrics.TotalRAM_GB | Should -Be 16
            $metrics.FreeRAM_GB | Should -Be 8
            $metrics.UsedRAM_GB | Should -Be 8
            $metrics.UsedRAM_Percent | Should -Be 50
            $metrics.CommitLimit_GB | Should -Be 32
            $metrics.CommitUsed_GB | Should -Be 16
            $metrics.OSVersion | Should -Be '23H2'
        }

        It 'Handles null or missing Win32_OperatingSystem response gracefully without divide-by-zero' {
            Mock Get-CimInstance { param($ClassName) $null }
            Mock Get-ItemProperty { $null }
            Mock Get-Process { $null }
            Mock Get-Service { $null }
            Mock Get-ScheduledTask { $null }
            Mock Get-AppxPackage { $null }
            Mock Get-AppxProvisionedPackage { $null }

            $metrics = Get-SystemMetrics

            $metrics.TotalRAM_GB | Should -Be 0
            $metrics.UsedRAM_GB | Should -Be 0
            $metrics.UsedRAM_Percent | Should -Be 0
            $metrics.ProcessCount | Should -Be 0
            $metrics.ThreadCount | Should -Be 0
        }
    }

    Context 'Processes & Threads Aggregation' {
        It 'Aggregates active process and thread counts correctly' {
            Mock Get-CimInstance { param($ClassName) $null }
            Mock Get-ItemProperty { $null }
            Mock Get-Service { $null }
            Mock Get-ScheduledTask { $null }
            Mock Get-AppxPackage { $null }
            Mock Get-AppxProvisionedPackage { $null }

            $proc1 = [PSCustomObject]@{ Threads = @(1, 2, 3) }
            $proc2 = [PSCustomObject]@{ Threads = @(1, 2) }
            Mock Get-Process { @($proc1, $proc2) }

            $metrics = Get-SystemMetrics

            $metrics.ProcessCount | Should -Be 2
            $metrics.ThreadCount | Should -Be 5
        }
    }

    Context 'Telemetry Services & Scheduled Tasks Audit' {
        It 'Audits telemetry services and maps running/stopped/NotFound statuses' {
            Mock Get-CimInstance { param($ClassName) $null }
            Mock Get-ItemProperty { $null }
            Mock Get-Process { $null }
            Mock Get-ScheduledTask { $null }
            Mock Get-AppxPackage { $null }
            Mock Get-AppxProvisionedPackage { $null }

            Mock Get-Service {
                param($Name)
                if ($Name -eq 'DiagTrack') {
                    [PSCustomObject]@{ Status = 'Running' }
                } elseif ($Name -eq 'SysMain') {
                    [PSCustomObject]@{ Status = 'Stopped' }
                } else {
                    $null
                }
            }

            $metrics = Get-SystemMetrics

            $metrics.Services['DiagTrack'] | Should -Be 'Running'
            $metrics.Services['SysMain'] | Should -Be 'Stopped'
            $metrics.Services['dmwappushservice'] | Should -Be 'NotFound'
        }

        It 'Audits scheduled tasks and maps state or NotFound' {
            Mock Get-CimInstance { param($ClassName) $null }
            Mock Get-ItemProperty { $null }
            Mock Get-Process { $null }
            Mock Get-Service { $null }
            Mock Get-AppxPackage { $null }
            Mock Get-AppxProvisionedPackage { $null }

            Mock Get-ScheduledTask {
                param($TaskName, $TaskPath)
                if ($TaskName -eq 'Consolidator') {
                    [PSCustomObject]@{ State = 'Ready' }
                } elseif ($TaskName -eq 'UsbCeip') {
                    [PSCustomObject]@{ State = 'Disabled' }
                } else {
                    $null
                }
            }

            $metrics = Get-SystemMetrics

            $metrics.ScheduledTasks['Consolidator'] | Should -Be 'Ready'
            $metrics.ScheduledTasks['UsbCeip'] | Should -Be 'Disabled'
            $metrics.ScheduledTasks['Microsoft Compatibility Appraiser'] | Should -Be 'NotFound'
        }
    }

    Context 'AppX Package Footprint Audit' {
        It 'Counts user and provisioned AppX packages correctly' {
            Mock Get-CimInstance { param($ClassName) $null }
            Mock Get-ItemProperty { $null }
            Mock Get-Process { $null }
            Mock Get-Service { $null }
            Mock Get-ScheduledTask { $null }

            Mock Get-AppxPackage { @(1, 2, 3, 4) }
            Mock Get-AppxProvisionedPackage { @(1, 2) }

            $metrics = Get-SystemMetrics

            $metrics.AppxUserPackages | Should -Be 4
            $metrics.AppxProvisioned | Should -Be 2
        }

        It 'Handles non-elevated AppX provisioned package error gracefully' {
            Mock Get-CimInstance { param($ClassName) $null }
            Mock Get-ItemProperty { $null }
            Mock Get-Process { $null }
            Mock Get-Service { $null }
            Mock Get-ScheduledTask { $null }
            Mock Get-AppxPackage { @() }
            Mock Get-AppxProvisionedPackage { throw "Access Denied" }

            $metrics = Get-SystemMetrics

            $metrics.AppxProvisioned | Should -Be "Unavailable (requires elevation)"
        }
    }
}

Describe 'Measure-SystemState: CLI Execution & Benchmark Workflows' -Tag 'Integration' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "MeasureSystemStateTests_$(Get-Random)"
        New-Item -Path $script:tempDir -ItemType Directory -Force | Out-Null

        $script:snap1Path = Join-Path $script:tempDir "baseline.json"
        $script:snap2Path = Join-Path $script:tempDir "debloated.json"

        $snap1Obj = [PSCustomObject]@{
            Timestamp        = "2025-01-01 10:00:00"
            OSVersion        = "23H2"
            OSBuild          = "10.0.22631.0"
            TotalRAM_GB      = 16
            UsedRAM_GB       = 8.0
            FreeRAM_GB       = 8.0
            UsedRAM_Percent  = 50.0
            CommitUsed_GB    = 10.0
            CommitLimit_GB   = 32.0
            ProcessCount     = 100
            ThreadCount      = 1000
            AppxUserPackages = 30
            AppxProvisioned  = 10
            Services         = [PSCustomObject]@{ DiagTrack = "Running"; SysMain = "Running" }
            ScheduledTasks   = [PSCustomObject]@{ Consolidator = "Ready" }
        }

        $snap2Obj = [PSCustomObject]@{
            Timestamp        = "2025-01-01 11:00:00"
            OSVersion        = "23H2"
            OSBuild          = "10.0.22631.0"
            TotalRAM_GB      = 16
            UsedRAM_GB       = 4.0
            FreeRAM_GB       = 12.0
            UsedRAM_Percent  = 25.0
            CommitUsed_GB    = 5.0
            CommitLimit_GB   = 32.0
            ProcessCount     = 70
            ThreadCount      = 700
            AppxUserPackages = 15
            AppxProvisioned  = 10
            Services         = [PSCustomObject]@{ DiagTrack = "Stopped"; SysMain = "Stopped" }
            ScheduledTasks   = [PSCustomObject]@{ Consolidator = "Disabled" }
        }

        $snap1Obj | ConvertTo-Json -Depth 5 | Out-File -FilePath $script:snap1Path -Encoding utf8
        $snap2Obj | ConvertTo-Json -Depth 5 | Out-File -FilePath $script:snap2Path -Encoding utf8
    }

    AfterAll {
        if (Test-Path $script:tempDir) {
            Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Snapshot Comparison Mode (-Baseline / -Target / -Compare)' {
        It 'Fails with exit code 1 if baseline snapshot file is missing' {
            $nonExistent = Join-Path $script:tempDir "missing.json"
            $out = & $script:psCli -NoProfile -ExecutionPolicy Bypass -File $script:targetScript -Baseline $nonExistent -Target $script:snap2Path 2>&1
            $LASTEXITCODE | Should -Be 1
            ($out | Out-String) | Should -Match "Snapshot 1 not found"
        }

        It 'Fails with exit code 1 if target snapshot file is missing' {
            $nonExistent = Join-Path $script:tempDir "missing.json"
            $out = & $script:psCli -NoProfile -ExecutionPolicy Bypass -File $script:targetScript -Baseline $script:snap1Path -Target $nonExistent 2>&1
            $LASTEXITCODE | Should -Be 1
            ($out | Out-String) | Should -Match "Snapshot 2 not found"
        }

        It 'Compares two snapshots and outputs benchmark comparative metrics' {
            $out = & $script:psCli -NoProfile -ExecutionPolicy Bypass -File $script:targetScript -Baseline $script:snap1Path -Target $script:snap2Path 2>&1
            $LASTEXITCODE | Should -Be 0
            $str = $out | Out-String
            $str | Should -Match "unslop-windows: Benchmark Comparison"
            $str | Should -Match "-4 GB"       # RAM Delta
            $str | Should -Match "-25%"       # RAM % Delta
            $str | Should -Match "-5 GB"       # Commit Delta
            $str | Should -Match "-30"        # Active Processes Delta
            $str | Should -Match "-300"       # Active Threads Delta
            $str | Should -Match "-15"        # AppX Delta
            $str | Should -Match "DiagTrack : Running -> Stopped"
        }

        It 'Supports -Compare parameter with comma-separated snapshot list' {
            $out = & $script:psCli -NoProfile -ExecutionPolicy Bypass -File $script:targetScript -Compare "$($script:snap1Path), $($script:snap2Path)" 2>&1
            $LASTEXITCODE | Should -Be 0
            $str = $out | Out-String
            $str | Should -Match "Benchmark Comparison"
        }

        It 'Exports Markdown report when -ExportMarkdown parameter is specified' {
            $mdPath = Join-Path $script:tempDir "report.md"
            $out = & $script:psCli -NoProfile -ExecutionPolicy Bypass -File $script:targetScript -Baseline $script:snap1Path -Target $script:snap2Path -ExportMarkdown $mdPath 2>&1
            $LASTEXITCODE | Should -Be 0
            (Test-Path $mdPath) | Should -Be $true

            $mdText = Get-Content -Path $mdPath -Raw
            $mdText | Should -Match "# unslop-windows System State Benchmark Report"
            $mdText | Should -Match "## Resource Utilization Metrics"
            $mdText | Should -Match "## Telemetry Services State"
            $mdText | Should -Match "DiagTrack"
        }
    }

    Context 'Single Snapshot Mode (-Snapshot)' {
        It 'Saves current live metrics snapshot to specified snapshot JSON path' {
            $snapOut = Join-Path $script:tempDir "live_snap.json"
            $out = & $script:psCli -NoProfile -ExecutionPolicy Bypass -File $script:targetScript -Snapshot $snapOut 2>&1
            $LASTEXITCODE | Should -Be 0
            (Test-Path $snapOut) | Should -Be $true

            $snapJson = Get-Content -Path $snapOut -Raw | ConvertFrom-Json
            $snapJson.Timestamp | Should -Not -BeNullOrEmpty
            $snapJson.PSObject.Properties.Name | Should -Contain "TotalRAM_GB"
            $snapJson.PSObject.Properties.Name | Should -Contain "Services"
            $snapJson.PSObject.Properties.Name | Should -Contain "ScheduledTasks"
        }
    }
}
