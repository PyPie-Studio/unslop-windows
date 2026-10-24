#requires -Version 5.1
<#
.SYNOPSIS
    Pester Unit & Mocking Test Suite for unslop-windows (Windows 10 Edition).
    Tests engine functions, dot-sourcing isolation, mock-intercepted mutations,
    parameter switches and the non-elevated security contract for unslop-win10.ps1.
#>

BeforeAll {
    $script:repoRoot = Split-Path -Parent $PSScriptRoot
    $script:targetScript = Join-Path $script:repoRoot "unslop-win10.ps1"

    if (-not (Test-Path $script:targetScript)) {
        throw "Target engine script not found at: $script:targetScript"
    }

    # Resolve preferred PowerShell CLI executable
    $script:psCli = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell.exe" }

    # Cross-Platform Stub Definitions: ensure Windows cmdlets can be mocked on non-Windows hosts
    if (-not (Get-Command Get-Service -ErrorAction SilentlyContinue)) {
        function Get-Service { param($Name) }
    }
    if (-not (Get-Command Stop-Service -ErrorAction SilentlyContinue)) {
        function Stop-Service { param($Name, $Force, $ErrorAction) }
    }
    if (-not (Get-Command Set-Service -ErrorAction SilentlyContinue)) {
        function Set-Service { param($Name, $StartupType, $ErrorAction) }
    }
    if (-not (Get-Command Start-Service -ErrorAction SilentlyContinue)) {
        function Start-Service { param($Name, $ErrorAction) }
    }
    if (-not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)) {
        function Get-ScheduledTask { param($TaskPath, $TaskName) }
    }
    if (-not (Get-Command Disable-ScheduledTask -ErrorAction SilentlyContinue)) {
        function Disable-ScheduledTask { param($TaskPath, $TaskName) }
    }
    if (-not (Get-Command Enable-ScheduledTask -ErrorAction SilentlyContinue)) {
        function Enable-ScheduledTask { param($TaskPath, $TaskName) }
    }
    if (-not $IsWindows -and $env:OS -ne "Windows_NT") {
        function Set-ItemProperty { param($Path, $Name, $Value, $Type, $ErrorAction, $Force) }
        function Remove-ItemProperty { param($Path, $Name, $Force, $ErrorAction) }
    }

    # Dot-source engine to export helper functions into test session
    . $script:targetScript
}

Describe 'unslop-windows (Win10): Engine Architecture & Dot-Sourcing' -Tag 'Unit', 'Core' {
    It 'Dot-sourcing exports all core engine functions into caller scope' {
        $expectedFunctions = @(
            'Log',
            'Set-SvcState',
            'Set-TaskState',
            'Set-RegDwordSafe',
            'Remove-RegValueSafe',
            'Set-RegStringSafe',
            'Set-ConsentCapability',
            'Get-MatchedStartupEntries',
            'Remove-StartupEntry'
        )

        foreach ($fn in $expectedFunctions) {
            $cmd = Get-Command -Name $fn -ErrorAction SilentlyContinue
            $cmd | Should -Not -BeNullOrEmpty -Because "Function '$fn' must be exported when unslop-win10.ps1 is dot-sourced"
            $cmd.CommandType.ToString() | Should -Be 'Function'
        }
    }

    It 'Dot-sourcing halts execution before procedural debloat modules without mutating system' {
        $isolatedOutput = & $script:psCli -NoProfile -ExecutionPolicy Bypass -Command "
            `$script:log = @()
            . '$($script:targetScript)'
            `$script:log -join '`n'
        "
        $isolatedOutput | Should -Not -Match "1\. Services" -Because "Dot-source guard must prevent procedural execution"
    }
}

Describe 'unslop-windows (Win10): Helper Function Unit Tests' -Tag 'Unit', 'Helpers' {
    BeforeEach {
        Mock -CommandName Write-Host -MockWith { }
    }
    Context 'Log' {
        BeforeEach {
            $script:log.Clear()
        }

        It 'Formats log entry with timestamp and appends to $script:log' {
            Mock -CommandName Write-Host -MockWith { }

            Log "Test log message"

            $script:log.Count | Should -Be 1
            $script:log[0] | Should -Match '^\[\d{2}:\d{2}:\d{2} (?:AM|PM)\] Test log message$'
            Should -Invoke -CommandName Write-Host -Times 1 -ParameterFilter {
                $Object -match '^\[\d{2}:\d{2}:\d{2} (?:AM|PM)\] Test log message$'
            }
        }

        It 'Formats log entry with [DRY-RUN] prefix when -DryRun is specified' {
            Mock -CommandName Write-Host -MockWith { }

            Log "Test dry run message" -DryRun

            $script:log.Count | Should -Be 1
            $script:log[0] | Should -Match '^\[\d{2}:\d{2}:\d{2} (?:AM|PM)\] \[DRY-RUN\] Test dry run message$'
            Should -Invoke -CommandName Write-Host -Times 1 -ParameterFilter {
                $Object -match '^\[\d{2}:\d{2}:\d{2} (?:AM|PM)\] \[DRY-RUN\] Test dry run message$'
            }
        }

        It 'Applies explicit -Color parameter overriding pattern matching' {
            Mock -CommandName Write-Host -MockWith { }

            Log "DISABLED: Test message" -Color "Yellow"

            Should -Invoke -CommandName Write-Host -Times 1 -ParameterFilter {
                $ForegroundColor -eq "Yellow"
            }
        }

        It 'Applies Cyan foreground color for header patterns' {
            Mock -CommandName Write-Host -MockWith { }

            $headerMessages = @("=== Title ===", "--- Subtitle ---", "=== unslop win10 ===")
            foreach ($msg in $headerMessages) {
                Log $msg
            }

            Should -Invoke -CommandName Write-Host -Times $headerMessages.Count -ParameterFilter {
                $ForegroundColor -eq "Cyan"
            }
        }

        It 'Applies Yellow foreground color for dry-run/would patterns' {
            Mock -CommandName Write-Host -MockWith { }

            $yellowMessages = @("  [WOULD REMOVE]: BloatwareApp", "DRY-RUN mode active")
            foreach ($msg in $yellowMessages) {
                Log $msg
            }

            Should -Invoke -CommandName Write-Host -Times $yellowMessages.Count -ParameterFilter {
                $ForegroundColor -eq "Yellow"
            }
        }

        It 'Applies Green foreground color for action completion keywords' {
            Mock -CommandName Write-Host -MockWith { }

            $greenKeywords = @('DISABLED:', 'REMOVED:', 'RESTORED:', 'ENABLED:', 'BLOCKED:', 'STOPPED:', 'UNINSTALLED:', 'SET:')
            foreach ($kw in $greenKeywords) {
                Log "  $kw TargetComponent"
            }

            Should -Invoke -CommandName Write-Host -Times $greenKeywords.Count -ParameterFilter {
                $ForegroundColor -eq "Green"
            }
        }

        It 'Applies DarkGray foreground color for SKIP pattern' {
            Mock -CommandName Write-Host -MockWith { }

            Log "  SKIP: Already disabled"

            Should -Invoke -CommandName Write-Host -Times 1 -ParameterFilter {
                $ForegroundColor -eq "DarkGray"
            }
        }

        It 'Applies Red foreground color for failure patterns' {
            Mock -CommandName Write-Host -MockWith { }

            $redKeywords = @('FAIL:', 'FAILED:', 'ERROR:')
            foreach ($kw in $redKeywords) {
                Log "  $kw Operation failed"
            }

            Should -Invoke -CommandName Write-Host -Times $redKeywords.Count -ParameterFilter {
                $ForegroundColor -eq "Red"
            }
        }

        It 'Applies Magenta foreground color for info/keep/note patterns' {
            Mock -CommandName Write-Host -MockWith { }

            $magentaKeywords = @('KEEP:', 'INFO:', 'NOTE:')
            foreach ($kw in $magentaKeywords) {
                Log "  $kw Preserving setting"
            }

            Should -Invoke -CommandName Write-Host -Times $magentaKeywords.Count -ParameterFilter {
                $ForegroundColor -eq "Magenta"
            }
        }

        It 'Calls Write-Host without ForegroundColor for default unmatched messages' {
            Mock -CommandName Write-Host -MockWith { }

            Log "Standard informative message without keywords"

            Should -Invoke -CommandName Write-Host -Times 1 -ParameterFilter {
                $null -eq $ForegroundColor -and $Object -match 'Standard informative message'
            }
        }
    }

    Context 'Set-RegDwordSafe' {
        It 'Debloat Mode: Calls Set-ItemProperty with debloatValue (zero calls to Remove-ItemProperty)' {
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Set-ItemProperty -MockWith { }
            Mock -CommandName Remove-ItemProperty -MockWith { }

            Set-RegDwordSafe -path "HKLM:\SOFTWARE\Policies\Test" -name "DisableTelemetry" -debloatValue 1 -undoValue 0

            Should -Invoke -CommandName Set-ItemProperty -Times 1 -ParameterFilter {
                $Path -eq "HKLM:\SOFTWARE\Policies\Test" -and
                $Name -eq "DisableTelemetry" -and
                $Value -eq 1 -and
                $Type -eq "DWord"
            }
            Should -Invoke -CommandName Remove-ItemProperty -Times 0
        }

        It 'Undo Mode (removeOnUndo = $false): Restores property with undoValue' {
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Set-ItemProperty -MockWith { }
            Mock -CommandName Remove-ItemProperty -MockWith { }

            Set-RegDwordSafe -path "HKLM:\SOFTWARE\Policies\Test" -name "DisableTelemetry" -debloatValue 1 -undoValue 0 -removeOnUndo $false -Undo

            Should -Invoke -CommandName Set-ItemProperty -Times 1 -ParameterFilter {
                $Path -eq "HKLM:\SOFTWARE\Policies\Test" -and
                $Name -eq "DisableTelemetry" -and
                $Value -eq 0 -and
                $Type -eq "DWord"
            }
            Should -Invoke -CommandName Remove-ItemProperty -Times 0
        }

        It 'Undo Mode (removeOnUndo = $true): Removes target registry property' {
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Set-ItemProperty -MockWith { }
            Mock -CommandName Remove-ItemProperty -MockWith { }

            Set-RegDwordSafe -path "HKLM:\SOFTWARE\Policies\Test" -name "CustomKillswitch" -debloatValue 1 -undoValue 0 -removeOnUndo $true -Undo

            Should -Invoke -CommandName Remove-ItemProperty -Times 1 -ParameterFilter {
                $Path -eq "HKLM:\SOFTWARE\Policies\Test" -and
                $Name -eq "CustomKillswitch"
            }
            Should -Invoke -CommandName Set-ItemProperty -Times 0
        }

        It 'Undo Mode (removeOnUndo = $true): Gracefully skips if property does not exist without incrementing FailCount' {
            $global:FailCount = 0
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Remove-ItemProperty -MockWith {
                throw [System.Management.Automation.PSArgumentException]::new("Property NonExistent does not exist at path HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Test.")
            }

            Set-RegDwordSafe -path "HKLM:\SOFTWARE\Policies\Test" -name "NonExistent" -debloatValue 1 -undoValue 0 -removeOnUndo $true -Undo

            $global:FailCount | Should -Be 0
        }

        It 'Undo Mode (removeOnUndo = $true): Gracefully skips when exception message contains "does not exist" without incrementing FailCount' {
            $global:FailCount = 0
            $script:log.Clear()
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Remove-ItemProperty -MockWith {
                throw [System.Exception]::new("Property NonExistent does not exist at path HKLM:\SOFTWARE\Policies\Test")
            }

            Set-RegDwordSafe -path "HKLM:\SOFTWARE\Policies\Test" -name "NonExistent" -debloatValue 1 -undoValue 0 -removeOnUndo $true -Undo

            $global:FailCount | Should -Be 0
            $script:log[-1] | Should -Match "SKIP: NonExistent not present in HKLM:\\SOFTWARE\\Policies\\Test"
        }

        It 'Undo Mode (removeOnUndo = $true): Traps unexpected Remove-ItemProperty exception, increments FailCount and emits FAILED log' {
            $global:FailCount = 0
            $script:log.Clear()
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Remove-ItemProperty -MockWith {
                throw [System.UnauthorizedAccessException]::new("Access is denied.")
            }

            Set-RegDwordSafe -path "HKLM:\SOFTWARE\Policies\Test" -name "LockedProperty" -debloatValue 1 -undoValue 0 -removeOnUndo $true -Undo

            $global:FailCount | Should -Be 1
            $script:log[-1] | Should -Match "FAILED: Could not remove LockedProperty from HKLM:\\SOFTWARE\\Policies\\Test"
        }

        It 'Dry-Run Mode: Performs zero mutating registry calls' {
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Set-ItemProperty -MockWith { }
            Mock -CommandName Remove-ItemProperty -MockWith { }
            Mock -CommandName New-Item -MockWith { }

            Set-RegDwordSafe -path "HKLM:\SOFTWARE\Policies\Test" -name "DryRunKey" -debloatValue 1 -undoValue 0 -DryRun
            Set-RegDwordSafe -path "HKLM:\SOFTWARE\Policies\Test" -name "DryRunKey" -debloatValue 1 -undoValue 0 -Undo -DryRun
            Set-RegDwordSafe -path "HKLM:\SOFTWARE\Policies\Test" -name "DryRunKey" -debloatValue 1 -undoValue 0 -removeOnUndo $true -Undo -DryRun

            Should -Invoke -CommandName Set-ItemProperty -Times 0
            Should -Invoke -CommandName Remove-ItemProperty -Times 0
            Should -Invoke -CommandName New-Item -Times 0
        }
    }

    Context 'Remove-RegValueSafe' {
        It 'Removes target registry property when present and logs REMOVED' {
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Get-ItemProperty -MockWith { [PSCustomObject]@{ LegacyVal = 1 } }
            Mock -CommandName Remove-ItemProperty -MockWith { }

            Remove-RegValueSafe -path "HKLM:\SOFTWARE\Policies\Test" -name "LegacyVal"

            Should -Invoke -CommandName Remove-ItemProperty -Times 1 -ParameterFilter {
                $Path -eq "HKLM:\SOFTWARE\Policies\Test" -and $Name -eq "LegacyVal"
            }
        }

        It 'Dry-Run Mode: Performs zero mutating registry calls' {
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Get-ItemProperty -MockWith { [PSCustomObject]@{ LegacyVal = 1 } }
            Mock -CommandName Remove-ItemProperty -MockWith { }

            Remove-RegValueSafe -path "HKLM:\SOFTWARE\Policies\Test" -name "LegacyVal" -DryRun

            Should -Invoke -CommandName Remove-ItemProperty -Times 0
        }

        It 'Gracefully skips non-existent property without incrementing FailCount' {
            $global:FailCount = 0
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Get-ItemProperty -MockWith { $null }
            Mock -CommandName Remove-ItemProperty -MockWith { }

            Remove-RegValueSafe -path "HKLM:\SOFTWARE\Policies\Test" -name "NonExistent"

            $global:FailCount | Should -Be 0
            Should -Invoke -CommandName Remove-ItemProperty -Times 0
        }

        It 'Gracefully skips when path does not exist' {
            Mock -CommandName Test-Path -MockWith { $false }
            Mock -CommandName Get-ItemProperty -MockWith { }
            Mock -CommandName Remove-ItemProperty -MockWith { }

            Remove-RegValueSafe -path "HKLM:\SOFTWARE\Policies\NonExistentPath" -name "TestVal"

            Should -Invoke -CommandName Get-ItemProperty -Times 0
            Should -Invoke -CommandName Remove-ItemProperty -Times 0
        }

        It 'Traps unexpected Remove-ItemProperty exception, increments FailCount and emits FAILED log' {
            $global:FailCount = 0
            $script:log.Clear()
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Get-ItemProperty -MockWith { [PSCustomObject]@{ LockedVal = 1 } }
            Mock -CommandName Remove-ItemProperty -MockWith {
                throw [System.UnauthorizedAccessException]::new("Access is denied.")
            }

            Remove-RegValueSafe -path "HKLM:\SOFTWARE\Policies\Test" -name "LockedVal"

            $global:FailCount | Should -Be 1
            ($script:log | Where-Object { $_ -match "FAILED: Could not remove LockedVal from HKLM:\\SOFTWARE\\Policies\\Test" }).Count | Should -BeGreaterThan 0
        }
    }

    Context 'Set-RegStringSafe' {
        It 'Creates key if missing and sets string registry property' {
            Mock -CommandName Test-Path -MockWith { $false }
            Mock -CommandName New-Item -MockWith { }
            Mock -CommandName Set-ItemProperty -MockWith { }

            Set-RegStringSafe -path "HKCU:\Software\Classes\CLSID\Test" -name "(default)" -value "TestString"

            Should -Invoke -CommandName New-Item -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Classes\CLSID\Test"
            }
            Should -Invoke -CommandName Set-ItemProperty -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Classes\CLSID\Test" -and
                $Name -eq "(default)" -and
                $Value -eq "TestString"
            }
        }

        It 'Dry-Run Mode: Performs zero mutating registry calls' {
            Mock -CommandName Test-Path -MockWith { $false }
            Mock -CommandName New-Item -MockWith { }
            Mock -CommandName Set-ItemProperty -MockWith { }

            Set-RegStringSafe -path "HKCU:\Software\Classes\CLSID\Test" -name "(default)" -value "TestString" -DryRun

            Should -Invoke -CommandName New-Item -Times 0
            Should -Invoke -CommandName Set-ItemProperty -Times 0
        }

        It 'Traps unexpected Set-ItemProperty exception, increments FailCount and emits FAILED log' {
            $global:FailCount = 0
            $script:log.Clear()
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Set-ItemProperty -MockWith {
                throw [System.UnauthorizedAccessException]::new("Access is denied.")
            }

            Set-RegStringSafe -path "HKCU:\Software\Classes\CLSID\Test" -name "(default)" -value "TestString"

            $global:FailCount | Should -Be 1
            ($script:log | Where-Object { $_ -match "FAILED: Could not set \(default\) in HKCU:\\Software\\Classes\\CLSID\\Test" }).Count | Should -BeGreaterThan 0
        }
    }

    Context 'Set-SvcState' {
        It 'Debloat Mode: Stops running service and disables startup' {
            Mock -CommandName Get-Service -MockWith {
                [PSCustomObject]@{ Name = "DiagTrack"; Status = "Running" }
            }
            Mock -CommandName Stop-Service -MockWith { }
            Mock -CommandName Set-Service -MockWith { }

            Set-SvcState -name "DiagTrack" -desc "Telemetry Service" -Undo:$false -DryRun:$false

            Should -Invoke -CommandName Stop-Service -Times 1 -ParameterFilter { $Name -eq "DiagTrack" }
            Should -Invoke -CommandName Set-Service -Times 1 -ParameterFilter { $Name -eq "DiagTrack" -and $StartupType -eq "Disabled" }
        }

        It 'Debloat Mode: Suppresses Stop-Service exceptions and successfully disables startup' {
            Mock -CommandName Get-Service -MockWith {
                [PSCustomObject]@{ Name = "DiagTrack"; Status = "Running" }
            }
            Mock -CommandName Stop-Service -MockWith { throw "Service cannot be stopped in its current state" }
            Mock -CommandName Set-Service -MockWith { }
            $global:FailCount = 0
            $script:log.Clear()

            Set-SvcState -name "DiagTrack" -desc "Telemetry Service" -Undo:$false -DryRun:$false

            Should -Invoke -CommandName Stop-Service -Times 1 -ParameterFilter { $Name -eq "DiagTrack" }
            Should -Invoke -CommandName Set-Service -Times 1 -ParameterFilter { $Name -eq "DiagTrack" -and $StartupType -eq "Disabled" }
            $global:FailCount | Should -Be 0
            ($script:log | Where-Object { $_ -match "DISABLED: DiagTrack \(Telemetry Service\)" }).Count | Should -Be 1
        }

        It 'Undo Mode: Re-enables service with specified StartupType and starts it' {
            Mock -CommandName Get-Service -MockWith {
                [PSCustomObject]@{ Name = "DiagTrack"; Status = "Stopped" }
            }
            Mock -CommandName Set-Service -MockWith { }
            Mock -CommandName Start-Service -MockWith { }

            Set-SvcState -name "DiagTrack" -desc "Telemetry Service" -undoStartupType "Automatic" -Undo:$true -DryRun:$false

            Should -Invoke -CommandName Set-Service -Times 1 -ParameterFilter { $Name -eq "DiagTrack" -and $StartupType -eq "Automatic" }
            Should -Invoke -CommandName Start-Service -Times 1 -ParameterFilter { $Name -eq "DiagTrack" }
        }

        It 'Missing Service: Gracefully skips non-existent services without invoking mutating cmdlets' {
            Mock -CommandName Get-Service -MockWith { $null }
            Mock -CommandName Stop-Service -MockWith { }
            Mock -CommandName Set-Service -MockWith { }
            Mock -CommandName Start-Service -MockWith { }

            Set-SvcState -name "NonExistentSvc" -desc "Skip Test" -Undo:$false -DryRun:$false

            Should -Invoke -CommandName Stop-Service -Times 0
            Should -Invoke -CommandName Set-Service -Times 0
            Should -Invoke -CommandName Start-Service -Times 0
        }

        It 'Dry-Run Mode: Performs zero mutating service calls' {
            Mock -CommandName Get-Service -MockWith {
                [PSCustomObject]@{ Name = "DiagTrack"; Status = "Running" }
            }
            Mock -CommandName Stop-Service -MockWith { }
            Mock -CommandName Set-Service -MockWith { }
            Mock -CommandName Start-Service -MockWith { }

            Set-SvcState -name "DiagTrack" -desc "Telemetry Service" -DryRun
            Set-SvcState -name "DiagTrack" -desc "Telemetry Service" -Undo -DryRun

            Should -Invoke -CommandName Stop-Service -Times 0
            Should -Invoke -CommandName Set-Service -Times 0
            Should -Invoke -CommandName Start-Service -Times 0
        }
    }

    Context 'Set-TaskState' {
        It 'Debloat Mode: Disables scheduled task if present' {
            Mock -CommandName Get-ScheduledTask -MockWith {
                [PSCustomObject]@{ TaskName = "Consolidator"; TaskPath = "\Microsoft\Windows\Customer Experience Improvement Program\" }
            }
            Mock -CommandName Disable-ScheduledTask -MockWith { }
            Mock -CommandName Enable-ScheduledTask -MockWith { }

            Set-TaskState -path "\Microsoft\Windows\Customer Experience Improvement Program\" -name "Consolidator" -Undo:$false -DryRun:$false

            Should -Invoke -CommandName Disable-ScheduledTask -Times 1 -ParameterFilter {
                $TaskName -eq "Consolidator" -and $TaskPath -eq "\Microsoft\Windows\Customer Experience Improvement Program\"
            }
            Should -Invoke -CommandName Enable-ScheduledTask -Times 0
        }

        It 'Undo Mode: Enables scheduled task if present' {
            Mock -CommandName Get-ScheduledTask -MockWith {
                [PSCustomObject]@{ TaskName = "Consolidator"; TaskPath = "\Microsoft\Windows\Customer Experience Improvement Program\" }
            }
            Mock -CommandName Disable-ScheduledTask -MockWith { }
            Mock -CommandName Enable-ScheduledTask -MockWith { }

            Set-TaskState -path "\Microsoft\Windows\Customer Experience Improvement Program\" -name "Consolidator" -Undo:$true -DryRun:$false

            Should -Invoke -CommandName Enable-ScheduledTask -Times 1 -ParameterFilter {
                $TaskName -eq "Consolidator" -and $TaskPath -eq "\Microsoft\Windows\Customer Experience Improvement Program\"
            }
            Should -Invoke -CommandName Disable-ScheduledTask -Times 0
        }

        It 'SYSTEM-only SDDL: Skips tasks with SYSTEM-only security descriptors on Access Denied without incrementing FailCount' {
            $mockProtectedTask = [PSCustomObject]@{
                TaskName           = "ModelCachingLimit"
                TaskPath           = "\Microsoft\Windows\WindowsAI\ClickToDo\"
                SecurityDescriptor = "D:P(A;;GA;;;SY)(A;;FRFX;;;BA)"
            }
            Mock -CommandName Get-ScheduledTask -MockWith { $mockProtectedTask }
            Mock -CommandName Disable-ScheduledTask -MockWith {
                throw [System.UnauthorizedAccessException]::new("Access is denied.")
            }
            Mock -CommandName Enable-ScheduledTask -MockWith { }

            $initialFails = $global:FailCount
            Set-TaskState -path "\Microsoft\Windows\WindowsAI\ClickToDo\" -name "ModelCachingLimit"

            $global:FailCount | Should -Be $initialFails
            ($script:log | Where-Object { $_ -match "SKIP: ModelCachingLimit requires SYSTEM token" }).Count | Should -BeGreaterThan 0
        }

        It 'Dry-Run Mode: Performs zero mutating task calls' {
            Mock -CommandName Get-ScheduledTask -MockWith {
                [PSCustomObject]@{ TaskName = "Consolidator"; TaskPath = "\Microsoft\Windows\Customer Experience Improvement Program\" }
            }
            Mock -CommandName Disable-ScheduledTask -MockWith { }
            Mock -CommandName Enable-ScheduledTask -MockWith { }

            Set-TaskState -path "\Microsoft\Windows\Customer Experience Improvement Program\" -name "Consolidator" -DryRun
            Set-TaskState -path "\Microsoft\Windows\Customer Experience Improvement Program\" -name "Consolidator" -Undo -DryRun

            Should -Invoke -CommandName Disable-ScheduledTask -Times 0
            Should -Invoke -CommandName Enable-ScheduledTask -Times 0
        }

        It 'Performance Optimization: Uses provided $TaskObject and bypasses Get-ScheduledTask query' {
            $mockTask = [PSCustomObject]@{
                TaskName = "Consolidator"
                TaskPath = "\Microsoft\Windows\Customer Experience Improvement Program\"
            }
            Mock -CommandName Get-ScheduledTask -MockWith { throw "Get-ScheduledTask should not be called when TaskObject is provided" }
            Mock -CommandName Disable-ScheduledTask -MockWith { }

            Set-TaskState -path "\Microsoft\Windows\Customer Experience Improvement Program\" -name "Consolidator" -TaskObject $mockTask

            Should -Invoke -CommandName Get-ScheduledTask -Times 0
            Should -Invoke -CommandName Disable-ScheduledTask -Times 1 -ParameterFilter {
                $TaskPath -eq "\Microsoft\Windows\Customer Experience Improvement Program\" -and $TaskName -eq "Consolidator"
            }
        }

        It 'Fallback Behavior: Queries Get-ScheduledTask when $TaskObject is null' {
            $mockTask = [PSCustomObject]@{
                TaskName = "Consolidator"
                TaskPath = "\Microsoft\Windows\Customer Experience Improvement Program\"
            }
            Mock -CommandName Get-ScheduledTask -MockWith { $mockTask }
            Mock -CommandName Disable-ScheduledTask -MockWith { }

            Set-TaskState -path "\Microsoft\Windows\Customer Experience Improvement Program\" -name "Consolidator" -TaskObject $null

            Should -Invoke -CommandName Get-ScheduledTask -Times 1
            Should -Invoke -CommandName Disable-ScheduledTask -Times 1
        }
    }

    Context 'Set-ConsentCapability' {
        It 'Debloat Mode: Creates consent path with New-Item when path does not exist' {
            Mock -CommandName Test-Path -MockWith { $false }
            Mock -CommandName New-Item -MockWith { }
            Mock -CommandName Set-ItemProperty -MockWith { }

            Set-ConsentCapability -capability "location" -desc "Location Tracking" -Undo:$false -DryRun:$false

            Should -Invoke -CommandName New-Item -Times 1 -ParameterFilter {
                $Path -match "ConsentStore\\location$"
            }
            Should -Invoke -CommandName Set-ItemProperty -Times 1 -ParameterFilter {
                $Path -match "ConsentStore\\location$" -and
                $Name -eq "Value" -and
                $Value -eq "Deny"
            }
        }

        It 'Debloat Mode: Sets capability consent to Deny' {
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Set-ItemProperty -MockWith { }

            Set-ConsentCapability -capability "location" -desc "Location Tracking" -Undo:$false -DryRun:$false

            Should -Invoke -CommandName Set-ItemProperty -Times 1 -ParameterFilter {
                $Path -match "ConsentStore\\location$" -and
                $Name -eq "Value" -and
                $Value -eq "Deny"
            }
        }

        It 'Undo Mode: Restores capability consent to Allow' {
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Set-ItemProperty -MockWith { }

            Set-ConsentCapability -capability "location" -desc "Location Tracking" -Undo:$true -DryRun:$false

            Should -Invoke -CommandName Set-ItemProperty -Times 1 -ParameterFilter {
                $Path -match "ConsentStore\\location$" -and
                $Name -eq "Value" -and
                $Value -eq "Allow"
            }
        }

        It 'Dry-Run Mode: Performs zero mutating consent calls' {
            Mock -CommandName Test-Path -MockWith { $false }
            Mock -CommandName New-Item -MockWith { }
            Mock -CommandName Set-ItemProperty -MockWith { }

            Set-ConsentCapability -capability "location" -desc "Location Tracking" -DryRun
            Set-ConsentCapability -capability "location" -desc "Location Tracking" -Undo -DryRun

            Should -Invoke -CommandName New-Item -Times 0
            Should -Invoke -CommandName Set-ItemProperty -Times 0
        }
    }

    Context 'Get-MatchedStartupEntries' {
        It 'Returns empty array when registry key path does not exist or Get-ItemProperty returns null' {
            Mock -CommandName Get-ItemProperty -MockWith { $null }

            $result = Get-MatchedStartupEntries -keyPath "HKCU:\Software\NonExistent" -pattern "OneDrive"

            @($result).Count | Should -Be 0
        }

        It 'Matches startup entry by property Name' {
            $mockProps = [PSCustomObject]@{
                OneDrive = "C:\Program Files\Microsoft OneDrive\OneDrive.exe"
                EpicGames = "C:\Games\Epic.exe"
            }
            Mock -CommandName Get-ItemProperty -MockWith { $mockProps }

            $result = Get-MatchedStartupEntries -keyPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -pattern "OneDrive"

            @($result).Count | Should -Be 1
            $result[0].Name | Should -Be "OneDrive"
            $result[0].Value | Should -Be "C:\Program Files\Microsoft OneDrive\OneDrive.exe"
        }

        It 'Matches startup entry by property Value when Name does not match pattern' {
            $mockProps = [PSCustomObject]@{
                AppLauncher = "C:\Users\User\AppData\Local\Microsoft\OneDrive\OneDrive.exe"
                OtherApp = "C:\Tools\tool.exe"
            }
            Mock -CommandName Get-ItemProperty -MockWith { $mockProps }

            $result = Get-MatchedStartupEntries -keyPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -pattern "OneDrive"

            @($result).Count | Should -Be 1
            $result[0].Name | Should -Be "AppLauncher"
            $result[0].Value | Should -Match "OneDrive"
        }

        It 'Filters out intrinsic PowerShell provider properties' {
            $mockProps = [PSCustomObject]@{
                PSPath = "Microsoft.PowerShell.Core\Registry::HKCU\Run"
                PSParentPath = "Microsoft.PowerShell.Core\Registry::HKCU"
                PSChildName = "Run"
                PSDrive = "HKCU"
                PSProvider = "Microsoft.PowerShell.Core\Registry"
                ValidApp = "C:\Tools\PowerShellLauncher.exe"
            }
            Mock -CommandName Get-ItemProperty -MockWith { $mockProps }

            $result = Get-MatchedStartupEntries -keyPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -pattern "PowerShell"

            @($result).Count | Should -Be 1
            $result[0].Name | Should -Be "ValidApp"
        }

        It 'Filters exact intrinsic PowerShell properties while preserving entries like PSPathToMyApp and MyPSProviderApp' {
            $mockProps = [PSCustomObject]@{
                PSPath          = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
                PSParentPath    = "HKCU:\Software\Microsoft\Windows\CurrentVersion"
                PSChildName     = "Run"
                PSDrive         = "HKCU"
                PSProvider      = "Registry"
                PSPathToMyApp   = "C:\Program Files\MyApp\app.exe"
                MyPSProviderApp = "C:\Program Files\MyApp\provider.exe"
                TestStartupApp  = "C:\Program Files\TestApp\app.exe"
            }
            Mock -CommandName Get-ItemProperty -MockWith { $mockProps }

            $matched = Get-MatchedStartupEntries -keyPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -pattern "PSPath|MyPSProviderApp|TestStartupApp"

            $matchedNames = $matched | ForEach-Object { $_.Name }
            $matchedNames | Should -Contain "PSPathToMyApp"
            $matchedNames | Should -Contain "MyPSProviderApp"
            $matchedNames | Should -Contain "TestStartupApp"
            $matchedNames | Should -Not -Contain "PSPath"
            $matchedNames | Should -Not -Contain "PSParentPath"
            $matchedNames | Should -Not -Contain "PSChildName"
            $matchedNames | Should -Not -Contain "PSDrive"
            $matchedNames | Should -Not -Contain "PSProvider"
            $matched.Count | Should -Be 3
        }

        It 'Returns empty collection when no entries match the pattern' {
            $mockProps = [PSCustomObject]@{
                AppA = "C:\a.exe"
                AppB = "C:\b.exe"
            }
            Mock -CommandName Get-ItemProperty -MockWith { $mockProps }

            $result = Get-MatchedStartupEntries -keyPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -pattern "NonExistentPattern"

            @($result).Count | Should -Be 0
        }

        It 'Matches multiple entries when pattern matches multiple property Names or Values' {
            $mockProps = [PSCustomObject]@{
                Teams1 = "C:\Teams.exe"
                Teams2 = "C:\AppData\Teams.exe"
                Discord = "C:\Discord.exe"
            }
            Mock -CommandName Get-ItemProperty -MockWith { $mockProps }

            $result = Get-MatchedStartupEntries -keyPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -pattern "Teams"

            @($result).Count | Should -Be 2
            $result[0].Name | Should -Be "Teams1"
            $result[1].Name | Should -Be "Teams2"
        }
    }

    Context 'Remove-StartupEntry' {
        It 'Debloat Mode: Archives startup entry to backup key and removes from Run' {
            $mockProps = [PSCustomObject]@{
                TestStartupApp = "C:\Program Files\TestApp\app.exe"
            }
            Mock -CommandName Get-ItemProperty -MockWith { $mockProps }
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Set-ItemProperty -MockWith { }
            Mock -CommandName Remove-ItemProperty -MockWith { }

            Remove-StartupEntry -pattern "TestStartupApp" -runKeys @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run")

            Should -Invoke -CommandName Set-ItemProperty -Times 1 -ParameterFilter {
                $Path -match "StartupBackup" -and $Name -eq "TestStartupApp"
            }
            Should -Invoke -CommandName Remove-ItemProperty -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -and $Name -eq "TestStartupApp"
            }
        }

        It 'Undo Mode: Restores archived startup entry from backup key to Run' {
            $mockBackupProps = [PSCustomObject]@{
                TestStartupApp = "C:\Program Files\TestApp\app.exe"
            }
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Get-ItemProperty -MockWith { $mockBackupProps }
            Mock -CommandName Set-ItemProperty -MockWith { }
            Mock -CommandName Remove-ItemProperty -MockWith { }

            Remove-StartupEntry -pattern "TestStartupApp" -runKeys @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run") -Undo

            Should -Invoke -CommandName Set-ItemProperty -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -and $Name -eq "TestStartupApp"
            }
            Should -Invoke -CommandName Remove-ItemProperty -Times 1 -ParameterFilter {
                $Path -match "StartupBackup" -and $Name -eq "TestStartupApp"
            }
        }

        It 'Dry-Run Mode: Performs zero mutating calls during startup management' {
            $mockProps = [PSCustomObject]@{
                TestStartupApp = "C:\Program Files\TestApp\app.exe"
            }
            Mock -CommandName Get-ItemProperty -MockWith { $mockProps }
            Mock -CommandName Set-ItemProperty -MockWith { }
            Mock -CommandName Remove-ItemProperty -MockWith { }

            Remove-StartupEntry -pattern "TestStartupApp" -runKeys @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run") -DryRun

            Should -Invoke -CommandName Set-ItemProperty -Times 0
            Should -Invoke -CommandName Remove-ItemProperty -Times 0
        }

        It 'Edge Case: No matched entries in Get-MatchedStartupEntries results in zero mutating calls' {
            Mock -CommandName Get-ItemProperty -MockWith { $null }
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Set-ItemProperty -MockWith { }
            Mock -CommandName Remove-ItemProperty -MockWith { }
            Mock -CommandName New-Item -MockWith { }

            Remove-StartupEntry -pattern "NonExistentApp" -runKeys @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run")
            Remove-StartupEntry -pattern "NonExistentApp" -runKeys @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run") -Undo

            Should -Invoke -CommandName Set-ItemProperty -Times 0
            Should -Invoke -CommandName Remove-ItemProperty -Times 0
            Should -Invoke -CommandName New-Item -Times 0
        }
    }

    Context 'Failure Honesty & Negative Error Trapping' {
        It 'Set-RegDwordSafe traps exceptions, increments FailCount and emits FAILED log' {
            $global:FailCount = 0
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Set-ItemProperty -MockWith { throw [System.UnauthorizedAccessException]::new("Access is denied") }

            Set-RegDwordSafe -path "HKLM:\SOFTWARE\AccessDenied" -name "TestKey" -debloatValue 1 -undoValue 0 -DryRun:$false

            $global:FailCount | Should -Be 1 -Because "Failure counter must be incremented on catch"
            $script:log[-1] | Should -Match "FAILED: Could not set TestKey"
        }

        It 'Set-RegDwordSafe traps New-Item creation exceptions in debloat mode, increments FailCount and emits FAILED log' {
            $global:FailCount = 0
            $script:log.Clear()
            Mock -CommandName Test-Path -MockWith { $false }
            Mock -CommandName New-Item -MockWith { throw [System.UnauthorizedAccessException]::new("Failed to create registry path") }

            Set-RegDwordSafe -path "HKLM:\SOFTWARE\NonExistent" -name "TestKey" -debloatValue 1 -undoValue 0 -DryRun:$false

            $global:FailCount | Should -Be 1 -Because "Failure counter must be incremented on New-Item catch"
            $script:log[-1] | Should -Match "FAILED: Could not set TestKey in HKLM:\\SOFTWARE\\NonExistent"
        }

        It 'Set-RegDwordSafe traps New-Item creation exceptions in undo mode, increments FailCount and emits FAILED log' {
            $global:FailCount = 0
            $script:log.Clear()
            Mock -CommandName Test-Path -MockWith { $false }
            Mock -CommandName New-Item -MockWith { throw [System.UnauthorizedAccessException]::new("Failed to create registry path") }

            Set-RegDwordSafe -path "HKLM:\SOFTWARE\NonExistent" -name "TestKey" -debloatValue 1 -undoValue 0 -Undo -DryRun:$false

            $global:FailCount | Should -Be 1 -Because "Failure counter must be incremented on New-Item catch in undo mode"
            $script:log[-1] | Should -Match "FAILED: Could not restore TestKey in HKLM:\\SOFTWARE\\NonExistent"
        }

        It 'Set-SvcState traps exceptions in debloat mode, increments FailCount and emits FAILED log' {
            $global:FailCount = 0
            Mock -CommandName Get-Service -MockWith {
                [PSCustomObject]@{ Name = "LockedService"; Status = "Running" }
            }
            Mock -CommandName Stop-Service -MockWith { }
            Mock -CommandName Set-Service -MockWith { throw [System.InvalidOperationException]::new("Cannot disable service") }

            Set-SvcState -name "LockedService" -desc "Failure Test" -DryRun:$false

            $global:FailCount | Should -Be 1 -Because "Failure counter must increment on service exception"
            $script:log[-1] | Should -Match "FAILED: Could not disable service LockedService"
        }

        It 'Set-SvcState traps exceptions in undo mode when Set-Service fails, increments FailCount and emits FAILED log' {
            $global:FailCount = 0
            Mock -CommandName Get-Service -MockWith {
                [PSCustomObject]@{ Name = "LockedService"; Status = "Stopped" }
            }
            Mock -CommandName Set-Service -MockWith { throw [System.InvalidOperationException]::new("Cannot restore service startup") }

            Set-SvcState -name "LockedService" -desc "Failure Test" -undoStartupType "Automatic" -Undo:$true -DryRun:$false

            $global:FailCount | Should -Be 1 -Because "Failure counter must increment on service exception"
            $script:log[-1] | Should -Match "FAILED: Could not restore service LockedService"
        }

        It 'Set-SvcState traps exceptions in undo mode when Start-Service fails (Automatic), increments FailCount and emits FAILED log' {
            $global:FailCount = 0
            Mock -CommandName Get-Service -MockWith {
                [PSCustomObject]@{ Name = "LockedService"; Status = "Stopped" }
            }
            Mock -CommandName Set-Service -MockWith { }
            Mock -CommandName Start-Service -MockWith { throw [System.InvalidOperationException]::new("Service failed to start") }

            Set-SvcState -name "LockedService" -desc "Failure Test" -undoStartupType "Automatic" -Undo:$true -DryRun:$false

            $global:FailCount | Should -Be 1 -Because "Failure counter must increment on service exception"
            $script:log[-1] | Should -Match "FAILED: Could not restore service LockedService"
        }

        It 'Set-SvcState ignores Start-Service failure in undo mode when startup type is Manual (best-effort)' {
            $global:FailCount = 0
            Mock -CommandName Get-Service -MockWith {
                [PSCustomObject]@{ Name = "LockedService"; Status = "Stopped" }
            }
            Mock -CommandName Set-Service -MockWith { }
            Mock -CommandName Start-Service -MockWith { throw [System.InvalidOperationException]::new("Service cannot start immediately") }

            Set-SvcState -name "LockedService" -desc "Failure Test" -undoStartupType "Manual" -Undo:$true -DryRun:$false

            $global:FailCount | Should -Be 0 -Because "Manual startup start failure is best-effort and ignored"
            $script:log[-1] | Should -Match "RESTORED: LockedService \(Startup: Manual\)"
        }

        It 'Set-TaskState traps exceptions, increments FailCount and emits FAILED log (Debloat Mode)' {
            $global:FailCount = 0
            Mock -CommandName Get-ScheduledTask -MockWith {
                [PSCustomObject]@{ TaskName = "LockedTask"; TaskPath = "\" }
            }
            Mock -CommandName Disable-ScheduledTask -MockWith { throw [System.UnauthorizedAccessException]::new("Access Denied") }

            Set-TaskState -path "\" -name "LockedTask" -DryRun:$false

            $global:FailCount | Should -Be 1 -Because "Failure counter must increment on task exception"
            $script:log[-1] | Should -Match "FAILED: Could not disable task LockedTask"
        }

        It 'Set-TaskState traps exceptions, increments FailCount and emits FAILED log (Undo Mode)' {
            $global:FailCount = 0
            Mock -CommandName Get-ScheduledTask -MockWith {
                [PSCustomObject]@{ TaskName = "LockedTask"; TaskPath = "\" }
            }
            Mock -CommandName Enable-ScheduledTask -MockWith { throw [System.UnauthorizedAccessException]::new("Access Denied") }

            Set-TaskState -path "\" -name "LockedTask" -Undo:$true -DryRun:$false

            $global:FailCount | Should -Be 1 -Because "Failure counter must increment on task enable exception in undo mode"
            $script:log[-1] | Should -Match "FAILED: Could not enable task LockedTask"
        }

        It 'Set-TaskState handles SYSTEM token restricted task exception gracefully in Debloat Mode' {
            $global:FailCount = 0
            Mock -CommandName Get-ScheduledTask -MockWith {
                [PSCustomObject]@{ TaskName = "SystemTask"; TaskPath = "\"; SecurityDescriptor = "(A;;FRFX;;;BA)" }
            }
            Mock -CommandName Disable-ScheduledTask -MockWith { throw [System.UnauthorizedAccessException]::new("Access is denied") }

            Set-TaskState -path "\" -name "SystemTask" -Undo:$false -DryRun:$false

            $global:FailCount | Should -Be 0 -Because "SYSTEM token restricted tasks should be skipped without incrementing FailCount"
            $script:log[-1] | Should -Match "SKIP: SystemTask requires SYSTEM token"
        }

        It 'Set-TaskState handles SYSTEM token restricted task exception gracefully in Undo Mode' {
            $global:FailCount = 0
            Mock -CommandName Get-ScheduledTask -MockWith {
                [PSCustomObject]@{ TaskName = "SystemTask"; TaskPath = "\"; SecurityDescriptor = "(A;;FRFX;;;BA)" }
            }
            Mock -CommandName Enable-ScheduledTask -MockWith { throw [System.UnauthorizedAccessException]::new("Access is denied") }

            Set-TaskState -path "\" -name "SystemTask" -Undo:$true -DryRun:$false

            $global:FailCount | Should -Be 0 -Because "SYSTEM token restricted tasks should be skipped without incrementing FailCount"
            $script:log[-1] | Should -Match "SKIP: SystemTask requires SYSTEM token"
        }

        It 'Set-ConsentCapability traps exceptions, increments FailCount and emits FAILED log' {
            $global:FailCount = 0
            $script:log.Clear()
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Set-ItemProperty -MockWith { throw [System.UnauthorizedAccessException]::new("Access is denied") }

            Set-ConsentCapability -capability "location" -desc "Location Tracking" -Undo:$false -DryRun:$false

            $global:FailCount | Should -Be 1 -Because "Failure counter must increment on consent capability set exception"
            $script:log[-1] | Should -Match "FAILED: Could not block consent location"
        }

        It 'Set-ConsentCapability (Undo) traps exceptions, increments FailCount and emits FAILED log' {
            $global:FailCount = 0
            $script:log.Clear()
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Set-ItemProperty -MockWith { throw [System.UnauthorizedAccessException]::new("Access is denied") }

            Set-ConsentCapability -capability "location" -desc "Location Tracking" -Undo:$true -DryRun:$false

            $global:FailCount | Should -Be 1 -Because "Failure counter must increment on consent capability restore exception"
            $script:log[-1] | Should -Match "FAILED: Could not restore consent location"
        }

        It 'Set-ConsentCapability traps New-Item creation exceptions, increments FailCount and emits FAILED log' {
            $global:FailCount = 0
            $script:log.Clear()
            Mock -CommandName Test-Path -MockWith { $false }
            Mock -CommandName New-Item -MockWith { throw [System.UnauthorizedAccessException]::new("Access is denied") }

            Set-ConsentCapability -capability "location" -desc "Location Tracking" -Undo:$false -DryRun:$false

            $global:FailCount | Should -Be 1 -Because "Failure counter must increment on consent capability New-Item exception"
            $script:log[-1] | Should -Match "FAILED: Could not block consent location"
        }

        It 'Set-ConsentCapability (Undo) traps New-Item creation exceptions, increments FailCount and emits FAILED log' {
            $global:FailCount = 0
            $script:log.Clear()
            Mock -CommandName Test-Path -MockWith { $false }
            Mock -CommandName New-Item -MockWith { throw [System.UnauthorizedAccessException]::new("Access is denied") }

            Set-ConsentCapability -capability "location" -desc "Location Tracking" -Undo:$true -DryRun:$false

            $global:FailCount | Should -Be 1 -Because "Failure counter must increment on consent capability New-Item exception in Undo mode"
            $script:log[-1] | Should -Match "FAILED: Could not restore consent location"
        }

        It 'Remove-StartupEntry traps backup creation exceptions, increments FailCount and emits FAILED log' {
            $global:FailCount = 0
            $script:log.Clear()
            $mockProps = [PSCustomObject]@{
                TestStartupApp = "C:\Program Files\TestApp\test.exe"
            }
            Mock -CommandName Get-ItemProperty -MockWith { $mockProps }
            Mock -CommandName Test-Path -MockWith { $false }
            Mock -CommandName New-Item -MockWith { throw [System.UnauthorizedAccessException]::new("Access Denied") }

            Remove-StartupEntry -pattern "TestStartupApp" -runKeys @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run") -DryRun:$false

            $global:FailCount | Should -Be 1 -Because "Failure counter must increment on startup backup creation exception"
            $script:log[-1] | Should -Match "FAILED: Could not remove TestStartupApp from HKCU:"
        }

        It 'Remove-StartupEntry traps exceptions, increments FailCount and emits FAILED log' {
            $global:FailCount = 0
            $script:log.Clear()
            $mockProps = [PSCustomObject]@{
                TestStartupApp = "C:\Program Files\TestApp\test.exe"
            }
            Mock -CommandName Get-ItemProperty -MockWith { $mockProps }
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Set-ItemProperty -MockWith { }
            Mock -CommandName Remove-ItemProperty -MockWith { throw [System.UnauthorizedAccessException]::new("Access Denied") }

            Remove-StartupEntry -pattern "TestStartupApp" -runKeys @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run") -DryRun:$false

            $global:FailCount | Should -Be 1 -Because "Failure counter must increment on startup removal exception"
            $script:log[-1] | Should -Match "FAILED: Could not remove TestStartupApp from HKCU:"
        }

        It 'Remove-StartupEntry (Undo) traps exceptions, increments FailCount and emits FAILED log' {
            $global:FailCount = 0
            $script:log.Clear()
            $mockProps = [PSCustomObject]@{
                TestStartupApp = "C:\Program Files\TestApp\test.exe"
            }
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Get-ItemProperty -MockWith { $mockProps }
            Mock -CommandName Set-ItemProperty -MockWith { throw [System.UnauthorizedAccessException]::new("Access Denied") }

            Remove-StartupEntry -pattern "TestStartupApp" -runKeys @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run") -Undo -DryRun:$false

            $global:FailCount | Should -Be 1 -Because "Failure counter must increment on startup restore exception"
            $script:log[-1] | Should -Match "FAILED: Could not restore startup entry TestStartupApp in HKCU:"
        }
    }
}

Describe 'unslop-windows (Win10): Parameter Flags & Whitelist Invariants' -Tag 'Integration', 'CLI' {
    It 'Non-elevated run without -DryRun exits with code 1' {
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin) {
            $proc = Start-Process -FilePath $script:psCli -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$($script:targetScript)`"", "-SkipBuildCheck" -Wait -PassThru -WindowStyle Hidden
            $proc.ExitCode | Should -Be 1 -Because "Execution without admin privileges must exit with code 1"
        } else {
            Set-ItResult -Skipped -Because "Current shell is already elevated; skipping mutation test"
        }
    }

    It 'Non-elevated run with -DryRun exits with code 0' {
        $output = & $script:psCli -NoProfile -ExecutionPolicy Bypass -File $script:targetScript -DryRun -SkipBuildCheck 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -match "UNSLOP-WINDOWS: DEBLOAT & HARDEN COMPLETE").Length | Should -BeGreaterThan 0
    }

    It '-KeepXbox retains Xbox gaming services and preserves untouchable whitelist' {
        $output = & $script:psCli -NoProfile -ExecutionPolicy Bypass -File $script:targetScript -DryRun -SkipBuildCheck -KeepXbox 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -match "Gaming & Xbox services retained \(-KeepXbox enabled\)").Length | Should -BeGreaterThan 0
        ($output -match "\[WOULD DE-PROVISION\]:.*Microsoft\.GamingApp").Length | Should -Be 0
        ($output -match "\[WOULD DE-PROVISION\]:.*Microsoft\.XboxIdentityProvider").Length | Should -Be 0 -Because "XboxIdentityProvider is on the untouchable whitelist"
    }

    It '-KeepOneDrive retains OneDrive and skips file sync killswitch' {
        $output = & $script:psCli -NoProfile -ExecutionPolicy Bypass -File $script:targetScript -DryRun -SkipBuildCheck -KeepOneDrive 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -match "OneDrive retained \(-KeepOneDrive enabled\)").Length | Should -BeGreaterThan 0
        ($output -match "\[WOULD UNINSTALL\]: OneDrive").Length | Should -Be 0
        ($output -match "DisableFileSyncNGSC").Length | Should -Be 0
    }

    It '-KeepTodos retains Microsoft To-Do and excludes it from removal list' {
        $output = & $script:psCli -NoProfile -ExecutionPolicy Bypass -File $script:targetScript -DryRun -SkipBuildCheck -KeepTodos 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -match "Microsoft To Do retained \(-KeepTodos enabled\)").Length | Should -BeGreaterThan 0
        ($output -match "\[WOULD REMOVE APP\]: Microsoft\.Todos").Length | Should -Be 0
    }

    It '-KeepSysMain retains SysMain service' {
        $output = & $script:psCli -NoProfile -ExecutionPolicy Bypass -File $script:targetScript -DryRun -SkipBuildCheck -KeepSysMain 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -match "SysMain \(Superfetch\) retained \(-KeepSysMain enabled\)").Length | Should -BeGreaterThan 0
        ($output -match "\[WOULD DISABLE\]: SysMain").Length | Should -Be 0
    }

    It '-KeepSearch retains Windows Search Indexer service' {
        $output = & $script:psCli -NoProfile -ExecutionPolicy Bypass -File $script:targetScript -DryRun -SkipBuildCheck -KeepSearch 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -match "Windows Search Indexer retained \(-KeepSearch enabled\)").Length | Should -BeGreaterThan 0
        ($output -match "\[WOULD DISABLE\]: WSearch").Length | Should -Be 0
    }

    It '-KeepClock retains Windows Clock & Alarms' {
        $output = & $script:psCli -NoProfile -ExecutionPolicy Bypass -File $script:targetScript -DryRun -SkipBuildCheck -KeepClock 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -match "Windows Clock & Alarms retained \(-KeepClock enabled\)").Length | Should -BeGreaterThan 0
        ($output -match "\[WOULD REMOVE APP\]: Microsoft\.WindowsAlarms").Length | Should -Be 0
    }

    It '-KeepTeams retains Microsoft Teams applications' {
        $output = & $script:psCli -NoProfile -ExecutionPolicy Bypass -File $script:targetScript -DryRun -SkipBuildCheck -KeepTeams 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -match "Microsoft Teams retained \(-KeepTeams enabled\)").Length | Should -BeGreaterThan 0
        ($output -match "\[WOULD REMOVE APP\]: MicrosoftTeams").Length | Should -Be 0
        ($output -match "\[WOULD REMOVE APP\]: Microsoft\.MSTeams").Length | Should -Be 0
        ($output -match "\[WOULD REMOVE APP\]: Microsoft\.Teams").Length | Should -Be 0
    }

    It '-KeepPCManager retains Microsoft PC Manager and skips service shutdown' {
        $output = & $script:psCli -NoProfile -ExecutionPolicy Bypass -File $script:targetScript -DryRun -SkipBuildCheck -KeepPCManager 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -match "Microsoft PC Manager retained \(-KeepPCManager enabled\)").Length | Should -BeGreaterThan 0
        ($output -match "\[WOULD REMOVE APP\]: Microsoft\.MicrosoftPCManager").Length | Should -Be 0
        ($output -match "\[WOULD DISABLE\]: PCManager Service Store").Length | Should -Be 0
    }

    It '-KeepMail retains Windows Mail & Calendar and excludes it from removal list' {
        $output = & $script:psCli -NoProfile -ExecutionPolicy Bypass -File $script:targetScript -DryRun -SkipBuildCheck -KeepMail 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -match "Windows Mail & Calendar retained \(-KeepMail enabled\)").Length | Should -BeGreaterThan 0
        ($output -match "\[WOULD REMOVE APP\]: Microsoft\.WindowsCommunicationsApps").Length | Should -Be 0
    }

    It '-KeepPhoneLink retains Phone Link and excludes it from removal list' {
        $output = & $script:psCli -NoProfile -ExecutionPolicy Bypass -File $script:targetScript -DryRun -SkipBuildCheck -KeepPhoneLink 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -match "Phone Link retained \(-KeepPhoneLink enabled\)").Length | Should -BeGreaterThan 0
        ($output -match "\[WOULD REMOVE APP\]: Microsoft\.YourPhone").Length | Should -Be 0
    }

    It '-KeepSpotify retains Spotify and excludes it from removal list' {
        $output = & $script:psCli -NoProfile -ExecutionPolicy Bypass -File $script:targetScript -DryRun -SkipBuildCheck -KeepSpotify 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -match "Spotify application retained \(-KeepSpotify enabled\)").Length | Should -BeGreaterThan 0
        ($output -match "\[WOULD REMOVE APP\]: SpotifyAB\.SpotifyMusic").Length | Should -Be 0
    }

    It '-KeepStoreAutoUpdate retains Microsoft Store automatic app updates' {
        $output = & $script:psCli -NoProfile -ExecutionPolicy Bypass -File $script:targetScript -DryRun -SkipBuildCheck -KeepStoreAutoUpdate 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -match "Microsoft Store automatic updates retained \(-KeepStoreAutoUpdate enabled\)").Length | Should -BeGreaterThan 0
    }

    It '-NoRestart suppresses reboot prompts and executes clean exit' {
        $output = & $script:psCli -NoProfile -ExecutionPolicy Bypass -File $script:targetScript -DryRun -SkipBuildCheck -NoRestart 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -match "UNSLOP-WINDOWS: DEBLOAT & HARDEN COMPLETE").Length | Should -BeGreaterThan 0
    }

    It '-ForceRestart accepts parameter switch cleanly in DryRun mode' {
        $output = & $script:psCli -NoProfile -ExecutionPolicy Bypass -File $script:targetScript -DryRun -SkipBuildCheck -ForceRestart 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -match "UNSLOP-WINDOWS: DEBLOAT & HARDEN COMPLETE").Length | Should -BeGreaterThan 0
    }
}

Describe 'unslop-windows (Win10): 100% Symmetrical Restoration Contract (AST Parity)' -Tag 'Unit', 'Static', 'Symmetry' {
    BeforeAll {
        $script:tokens = $null
        $script:errors = $null
        $script:ast = [System.Management.Automation.Language.Parser]::ParseFile($script:targetScript, [ref]$script:tokens, [ref]$script:errors)
        $script:errors.Count | Should -Be 0
    }

    It 'Every Set-RegDwordSafe call defines both debloat and undo values with valid parameters' {
        $regCalls = $script:ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -eq 'Set-RegDwordSafe'
        }, $true)

        $regCalls.Count | Should -BeGreaterThan 25 -Because "Script must contain registry debloat operations"

        foreach ($call in $regCalls) {
            $cmdElements = $call.CommandElements
            $cmdText = $call.Extent.Text

            $hasDebloat = $false
            $hasUndo = $false

            for ($i = 1; $i -lt $cmdElements.Count; $i++) {
                $el = $cmdElements[$i]
                if ($el -is [System.Management.Automation.Language.CommandParameterAst]) {
                    if ($el.ParameterName -eq 'debloatValue') { $hasDebloat = $true }
                    if ($el.ParameterName -eq 'undoValue') { $hasUndo = $true }
                }
            }

            $nonParamElements = $cmdElements | Where-Object {
                $_ -isnot [System.Management.Automation.Language.CommandParameterAst] -and
                $_ -ne $cmdElements[0]
            }
            if ($nonParamElements.Count -ge 4) {
                $hasDebloat = $true
                $hasUndo = $true
            }

            $hasDebloat | Should -BeTrue -Because "Call '$cmdText' must supply debloatValue"
            $hasUndo | Should -BeTrue -Because "Call '$cmdText' must supply undoValue for -Undo symmetry"
        }
    }

    It 'Zero raw mutating cmdlets (registry, tasks, services) exist outside approved helper functions' {
        $approvedRegHelpers = @('Set-RegDwordSafe', 'Set-ConsentCapability', 'Remove-StartupEntry', 'Set-RegStringSafe', 'Remove-RegValueSafe')
        $mutatingRegCmdlets = @('Set-ItemProperty', 'New-ItemProperty', 'Remove-ItemProperty')
        $mutatingTaskCmdlets = @('Disable-ScheduledTask', 'Enable-ScheduledTask')
        $mutatingSvcCmdlets = @('Set-Service', 'Stop-Service', 'Start-Service')

        $nakedCalls = $script:ast.FindAll({
            param($node)
            if ($node -is [System.Management.Automation.Language.CommandAst]) {
                $name = $node.GetCommandName()
                if ($mutatingRegCmdlets -contains $name) {
                    $parent = $node.Parent
                    $inApprovedFunc = $false
                    while ($parent) {
                        if ($parent -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
                            if ($approvedRegHelpers -contains $parent.Name) {
                                $inApprovedFunc = $true
                                break
                            }
                        }
                        $parent = $parent.Parent
                    }
                    if (-not $inApprovedFunc) {
                        return $true
                    }
                }
                if ($mutatingTaskCmdlets -contains $name) {
                    $parent = $node.Parent
                    $inTaskFunc = $false
                    while ($parent) {
                        if ($parent -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $parent.Name -eq 'Set-TaskState') {
                            $inTaskFunc = $true
                            break
                        }
                        $parent = $parent.Parent
                    }
                    if (-not $inTaskFunc) {
                        return $true
                    }
                }
                if ($mutatingSvcCmdlets -contains $name) {
                    $parent = $node.Parent
                    $inSvcFunc = $false
                    while ($parent) {
                        if ($parent -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $parent.Name -eq 'Set-SvcState') {
                            $inSvcFunc = $true
                            break
                        }
                        $parent = $parent.Parent
                    }
                    if (-not $inSvcFunc) {
                        return $true
                    }
                }
            }
            return $false
        }, $true)

        $nakedCalls.Count | Should -Be 0 -Because "All mutations must be channeled through approved helper functions (Set-RegDwordSafe, Set-TaskState, Set-SvcState) for 100% undo symmetry and failure honesty"
    }

    It 'Every service managed via Set-SvcState defines a non-empty undo startup type' {
        $svcCalls = $script:ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -eq 'Set-SvcState'
        }, $true)

        $svcCalls.Count | Should -BeGreaterThan 5 -Because "Script must declare service states"

        foreach ($call in $svcCalls) {
            $cmdText = $call.Extent.Text
            $cmdText | Should -Not -Match '\$\s*null' -Because "Service state '$cmdText' must have valid restore startup type"
        }
    }

    It 'Manages compatibility appraisal and CDP services via Set-SvcState' {
        $expectedServices = @(
            'PcaSvc',
            'CDPSvc',
            'PCManager Service Store'
        )

        foreach ($svc in $expectedServices) {
            $script:ast.Extent.Text | Should -Match "`"$([regex]::Escape($svc))`"" -Because "Service '$svc' must be managed via Set-SvcState in unslop-win10.ps1"
        }
    }

    It 'Core engine helper functions maintain strict bidirectional symmetry' {
        $functions = $script:ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
        }, $true)

        $funcNames = $functions | ForEach-Object { $_.Name }
        $funcNames | Should -Contain 'Set-RegDwordSafe'
        $funcNames | Should -Contain 'Remove-RegValueSafe'
        $funcNames | Should -Contain 'Set-RegStringSafe'
        $funcNames | Should -Contain 'Set-SvcState'
        $funcNames | Should -Contain 'Set-TaskState'
        $funcNames | Should -Contain 'Set-ConsentCapability'
        $funcNames | Should -Contain 'Remove-StartupEntry'

        foreach ($fn in $functions) {
            if ($fn.Name -eq 'Set-RegDwordSafe') {
                $fn.Extent.Text | Should -Match 'if\s*\(\$Undo\)' -Because "Set-RegDwordSafe must evaluate `$Undo"
                $fn.Extent.Text | Should -Match 'Set-ItemProperty.*\$undoValue' -Because "Set-RegDwordSafe must support restoring undoValue"
                $fn.Extent.Text | Should -Match 'Remove-ItemProperty' -Because "Set-RegDwordSafe must support removeOnUndo"
            }
            if ($fn.Name -eq 'Remove-RegValueSafe') {
                $fn.Extent.Text | Should -Match 'Remove-ItemProperty' -Because "Remove-RegValueSafe must call Remove-ItemProperty"
                $fn.Extent.Text | Should -Match 'if\s*\(\$DryRun\)' -Because "Remove-RegValueSafe must check DryRun"
                $fn.Extent.Text | Should -Match '\$global:FailCount\+\+' -Because "Remove-RegValueSafe must increment FailCount on unhandled errors"
            }
            if ($fn.Name -eq 'Set-RegStringSafe') {
                $fn.Extent.Text | Should -Match 'Set-ItemProperty' -Because "Set-RegStringSafe must call Set-ItemProperty"
                $fn.Extent.Text | Should -Match 'if\s*\(\$DryRun\)' -Because "Set-RegStringSafe must check DryRun"
                $fn.Extent.Text | Should -Match '\$global:FailCount\+\+' -Because "Set-RegStringSafe must increment FailCount on unhandled errors"
            }
            if ($fn.Name -eq 'Set-SvcState') {
                $fn.Extent.Text | Should -Match 'if\s*\(\$Undo\)' -Because "Set-SvcState must evaluate `$Undo"
                $fn.Extent.Text | Should -Match 'Start-Service' -Because "Set-SvcState must restart service on undo"
                $fn.Extent.Text | Should -Match 'Stop-Service' -Because "Set-SvcState must stop service on debloat"
            }
            if ($fn.Name -eq 'Set-TaskState') {
                $fn.Extent.Text | Should -Match 'if\s*\(\$Undo\)' -Because "Set-TaskState must evaluate `$Undo"
                $fn.Extent.Text | Should -Match 'Enable-ScheduledTask' -Because "Set-TaskState must enable task on undo"
                $fn.Extent.Text | Should -Match 'Disable-ScheduledTask' -Because "Set-TaskState must disable task on debloat"
            }
            if ($fn.Name -eq 'Set-ConsentCapability') {
                $fn.Extent.Text | Should -Match 'if\s*\(\$Undo\)' -Because "Set-ConsentCapability must evaluate `$Undo"
                $fn.Extent.Text | Should -Match '\$undoValue' -Because "Set-ConsentCapability must restore undoValue"
            }
            if ($fn.Name -eq 'Remove-StartupEntry') {
                $fn.Extent.Text | Should -Match 'if\s*\(\$Undo\)' -Because "Remove-StartupEntry must evaluate `$Undo"
                $fn.Extent.Text | Should -Match 'StartupBackup' -Because "Remove-StartupEntry must utilize StartupBackup for restoration"
            }
        }
    }

    It 'Firewall hardening loop implements bidirectional rule transitions' {
        $fwBlock = $script:ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            ($node.GetCommandName() -match 'NetFirewallRule')
        }, $true)

        $fwCmds = $fwBlock | ForEach-Object { $_.GetCommandName() }
        $fwCmds | Should -Contain 'Disable-NetFirewallRule' -Because "Firewall hardening must block outbound telemetry rules"
        $fwCmds | Should -Contain 'Enable-NetFirewallRule' -Because "Firewall restoration must restore original firewall state on -Undo"
    }

    It 'Filters staged provisioned packages and installed app candidates in single-pass regex scans' {
        $script:ast.Extent.Text | Should -Match '\$stagedPackages\s*-and\s*\$bloatApps\.Count\s*-gt\s*0' -Because "Staged provisioned packages must be checked and filtered in a single pass"
        $script:ast.Extent.Text | Should -Match '\$candidateInstalled\s*=\s*if' -Because "Installed package candidates must be pre-filtered in a single pass"
    }
}

Describe 'unslop-windows (Win10): Security & Privilege Boundary Invariants' -Tag 'Security', 'Unit' {
    BeforeAll {
        if (-not $script:ast) {
            $script:tokens = $null
            $script:errors = $null
            $script:ast = [System.Management.Automation.Language.Parser]::ParseFile($script:targetScript, [ref]$script:tokens, [ref]$script:errors)
        }
    }
    It 'Enforces Authenticode signature verification on user-space executables' {
        $setupCalls = $script:ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -eq 'Get-AuthenticodeSignature'
        }, $true)

        $setupCalls.Count | Should -BeGreaterThan 0 -Because "Script must enforce Authenticode signature verification on user-space executables"
    }

    It 'Log and output path resolutions protect against reparse point / symlink redirection' {
        $reparseChecksEngine = $script:ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.MemberExpressionAst] -and
            $node.Member.Extent.Text -eq 'ReparsePoint'
        }, $true)

        $reparseChecksEngine.Count | Should -BeGreaterThan 0 -Because "Engine log initialization must inspect directory attributes for ReparsePoint to prevent symlink attacks"
    }

    It 'Windows Update driver updates are preserved and legacy ExcludeWUDrivers policy is cleaned up' {
        $wuBlocks = $script:ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
            $node.Value -eq 'ExcludeWUDriversInQualityUpdate'
        }, $true)

        $wuBlocks.Count | Should -BeGreaterThan 0 -Because "Script must inspect for legacy ExcludeWUDriversInQualityUpdate to clear it"
    }

    It 'Configures Defender SubmitSamplesConsent to 2 (NeverSend) on debloat and 1 on undo' {
        $mpCalls = $script:ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -eq 'Set-MpPreference'
        }, $true)

        $mpCalls.Count | Should -BeGreaterThan 0 -Because "Script must configure Set-MpPreference"
        $mpTexts = $mpCalls | ForEach-Object { $_.Extent.Text }
        $mpTexts | Should -Contain 'Set-MpPreference -SubmitSamplesConsent 2 -ErrorAction Stop' -Because "Debloat must use SubmitSamplesConsent = 2 (NeverSend)"
        $mpTexts | Should -Contain 'Set-MpPreference -SubmitSamplesConsent 1 -ErrorAction Stop' -Because "Undo must restore SubmitSamplesConsent = 1 (SendSafeSamples)"
        $mpTexts | Should -Not -Contain 'Set-MpPreference -SubmitSamplesConsent 0' -Because "SubmitSamplesConsent = 0 is AlwaysPrompt and must not be used"
    }

    It 'Does not contain non-removable core system packages in bloatware list' {
        $nonRemovables = @(
            'Microsoft.Windows.CloudExperienceHost',
            'Microsoft.Windows.PeopleExperienceHost',
            'Microsoft.Windows.ParentalControls',
            'Microsoft.Windows.NarratorQuickStart',
            'Microsoft.ECApp',
            'Microsoft.MicrosoftEdge.Stable',
            'Microsoft.MicrosoftEdgeDevToolsClient',
            'Microsoft.WindowsStore',
            'Microsoft.DesktopAppInstaller',
            'Microsoft.XboxIdentityProvider',
            'Microsoft.WindowsTerminal'
        )

        $bloatAssignment = $script:ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left.Extent.Text -eq '$bloatApps'
        }, $true) | Select-Object -First 1

        $bloatAssignment | Should -Not -BeNullOrEmpty -Because "Script must define `$bloatApps array"

        $stringLiterals = $bloatAssignment.Right.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.StringConstantExpressionAst]
        }, $true) | ForEach-Object { $_.Value }

        foreach ($pkg in $nonRemovables) {
            $stringLiterals | Should -Not -Contain $pkg -Because "$pkg is a NonRemovable or untouchable system component and must not be in `$bloatApps"
        }
    }

    It 'Never references unmounted HKCR drive in registry paths' {
        $script:ast.Extent.Text | Should -Not -Match 'HKCR:\\' -Because "PowerShell does not mount HKCR: by default; use HKLM:\SOFTWARE\Classes or HKCU:\Software\Classes"
    }

    It 'Configures Cortana policy AllowCortana symmetrically' {
        $script:ast.Extent.Text | Should -Match 'AllowCortana' -Because "Cortana must be disabled via AllowCortana policy"
    }

    It 'Configures News and Interests ShellFeedsTaskbarViewMode' {
        $script:ast.Extent.Text | Should -Match 'ShellFeedsTaskbarViewMode' -Because "News and Interests must be configured via Feeds policy"
    }

    It 'Configures PeopleBand and HideSCAMeetNow' {
        $script:ast.Extent.Text | Should -Match 'PeopleBand' -Because "People bar must be hidden"
        $script:ast.Extent.Text | Should -Match 'HideSCAMeetNow' -Because "Meet Now taskbar button must be hidden"
    }

    It 'Suppresses Connected Devices Platform (EnableCdp) and Store AutoDownload symmetrically' {
        $script:ast.Extent.Text | Should -Match 'EnableCdp' -Because "Connected Devices Platform policy must be configured"
        $script:ast.Extent.Text | Should -Match 'AutoDownload' -Because "Microsoft Store AutoDownload policy must be configured"
    }

    It 'Add-AppxPackage never binds invalid -AllUsers parameter' {
        $appxCalls = $script:ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -eq 'Add-AppxPackage'
        }, $true)

        $appxCalls.Count | Should -BeGreaterThan 0 -Because "Add-AppxPackage calls must be present in undo routines"
        foreach ($call in $appxCalls) {
            $call.Extent.Text | Should -Not -Match '-AllUsers' -Because "Add-AppxPackage does not accept -AllUsers (only Remove-AppxPackage supports -AllUsers)"
        }
    }

    It 'Enforces CloudContent policies (DisableWindowsConsumerFeatures, DisableCloudOptimizedContent, DisableConsumerAccountStateContent) symmetrically' {
        $script:ast.Extent.Text | Should -Match 'DisableWindowsConsumerFeatures' -Because "DisableWindowsConsumerFeatures GPO policy must be configured"
        $script:ast.Extent.Text | Should -Match 'DisableCloudOptimizedContent' -Because "DisableCloudOptimizedContent GPO policy must be configured"
        $script:ast.Extent.Text | Should -Match 'DisableConsumerAccountStateContent' -Because "DisableConsumerAccountStateContent GPO policy must be configured"
    }

    It 'Configures ContentDeliveryAllowed in ContentDeliveryManager' {
        $script:ast.Extent.Text | Should -Match '"ContentDeliveryAllowed"' -Because "ContentDeliveryAllowed master CDM switch must be configured"
    }

    It 'Targets fresh-install bloatware (Sudoku, LinkedIn, Teams, Copilot) in bloatApps array' {
        $script:ast.Extent.Text | Should -Match '"Microsoft\.MicrosoftSudoku"' -Because "Sudoku app must be targeted"
        $script:ast.Extent.Text | Should -Match '"7EE7776C\.LinkedInforWindows"' -Because "LinkedIn app must be targeted"
        $script:ast.Extent.Text | Should -Match '"MicrosoftTeams"' -Because "Personal Teams app must be targeted"
        $script:ast.Extent.Text | Should -Match '"Microsoft\.MSTeams"' -Because "Modern Teams app must be targeted"
        $script:ast.Extent.Text | Should -Match '"Microsoft\.Copilot"' -Because "Copilot app must be targeted"
        $script:ast.Extent.Text | Should -Match '"Microsoft\.Windows\.Ai\.Copilot\.Provider"' -Because "Copilot provider must be targeted"
    }

    It 'Targets Xbox Game Bar packages when -KeepXbox is not present' {
        $script:ast.Extent.Text | Should -Match '"Microsoft\.XboxGamingOverlay"' -Because "Xbox Game Bar package must be targeted"
        $script:ast.Extent.Text | Should -Match '"Microsoft\.XboxGameOverlay"' -Because "Xbox Game Overlay package must be targeted"
        $script:ast.Extent.Text | Should -Match '"Microsoft\.XboxSpeechToTextOverlay"' -Because "Xbox Speech to Text Overlay package must be targeted"
    }

    It 'Suppresses Windows Copilot policies and taskbar button symmetrically' {
        $script:ast.Extent.Text | Should -Match 'TurnOffWindowsCopilot' -Because "TurnOffWindowsCopilot policy must be configured"
        $script:ast.Extent.Text | Should -Match 'ShowCopilotButton' -Because "ShowCopilotButton taskbar setting must be configured"
    }

    It 'Suppresses Game Bar and Game DVR background capture policies symmetrically' {
        $script:ast.Extent.Text | Should -Match 'AppCaptureEnabled' -Because "AppCaptureEnabled GameDVR policy must be configured"
        $script:ast.Extent.Text | Should -Match 'HistoricalCaptureEnabled' -Because "HistoricalCaptureEnabled GameDVR policy must be configured"
        $script:ast.Extent.Text | Should -Match 'GameDVR_Enabled' -Because "GameDVR_Enabled must be configured"
        $script:ast.Extent.Text | Should -Match 'AllowGameDVR' -Because "AllowGameDVR machine policy must be configured"
    }

    It 'Suppresses Edge Copilot and HubsSidebar policies symmetrically' {
        $script:ast.Extent.Text | Should -Match 'HubsSidebarEnabled' -Because "Edge sidebar must be disabled via policy"
        $script:ast.Extent.Text | Should -Match 'AllowCopilot' -Because "Edge Copilot must be disabled via policy"
    }

    It 'Suppresses Chromium Edge startup boost and background tasks policies symmetrically' {
        $script:ast.Extent.Text | Should -Match 'StartupBoostEnabled' -Because "Edge startup boost must be disabled via policy"
        $script:ast.Extent.Text | Should -Match 'BackgroundModeEnabled' -Because "Edge background mode must be disabled via policy"
    }

    It 'Manages Xbox Live services symmetrically when -KeepXbox is not enabled' {
        $script:ast.Extent.Text | Should -Match '"XblAuthManager"' -Because "XblAuthManager service must be managed"
        $script:ast.Extent.Text | Should -Match '"XblGameSave"' -Because "XblGameSave service must be managed"
        $script:ast.Extent.Text | Should -Match '"XboxNetApiSvc"' -Because "XboxNetApiSvc service must be managed"
        $script:ast.Extent.Text | Should -Match '"XboxGipSvc"' -Because "XboxGipSvc service must be managed"
    }

    It 'Implements Search Highlights EnableDynamicContentInWSB, AllowSearchToUseLocation and AllowCloudSearch machine policies' {
        $script:ast.Extent.Text | Should -Match 'EnableDynamicContentInWSB' -Because "EnableDynamicContentInWSB must be configured"
        $script:ast.Extent.Text | Should -Match 'AllowSearchToUseLocation' -Because "AllowSearchToUseLocation must be configured"
        $script:ast.Extent.Text | Should -Match 'AllowCloudSearch' -Because "AllowCloudSearch must be configured"
    }

    It 'Enforces double-quoted FilePath arguments on Start-Process invocations' {
        $spCalls = $script:ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -eq 'Start-Process'
        }, $true)

        $spCalls.Count | Should -BeGreaterThan 0 -Because "Script must invoke Start-Process for external setup execution"
        foreach ($call in $spCalls) {
            $fpElem = $call.CommandElements | Where-Object { $_.Extent.Text -match '\$oneDriveUninstaller' }
            if ($fpElem) {
                $fpElem.Extent.Text | Should -Match '"\$oneDriveUninstaller"' -Because "Start-Process -FilePath must be double-quoted to prevent unquoted argument vulnerabilities"
            }
        }
    }

    It 'Enforces DISM and WinSxS component store inviolability (Zero destructive DISM or WinSxS tampering)' {
        $destructiveDism = $script:ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            ($node.GetCommandName() -match '^(dism|dism\.exe)$' -or $node.Extent.Text -match 'cleanup-image|startcomponentcleanup|resetbase')
        }, $true)
        $destructiveDism.Count | Should -Be 0 -Because "Destructive DISM cleanups break Cumulative Updates and are strictly forbidden"

        $winsxsTampering = $script:ast.FindAll({
            param($node)
            ($node -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
             $node -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) -and
            $node.Extent.Text -match 'WinSxS'
        }, $true)
        $winsxsTampering.Count | Should -Be 0 -Because "Direct WinSxS file or store tampering is strictly forbidden"
    }

    It 'Enforces offline-first architecture (Zero network cmdlets or ad-hoc script fetching)' {
        $networkCmdlets = @('Invoke-WebRequest', 'Invoke-RestMethod', 'curl', 'curl.exe', 'wget', 'wget.exe', 'Start-BitsTransfer', 'bitsadmin', 'bitsadmin.exe')
        $networkCalls = $script:ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            $networkCmdlets -contains $node.GetCommandName()
        }, $true)
        $networkCalls.Count | Should -Be 0 -Because "unslop-windows must be 100% offline-first and never fetch scripts or executables over the network"
    }

    It 'Declares -NoRestart and -ForceRestart parameters and handles reboot exit code 100' {
        $paramBlock = $script:ast.ParamBlock
        $paramBlock | Should -Not -BeNullOrEmpty -Because "Script must define param block"
        $paramNames = $paramBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath }
        $paramNames | Should -Contain 'NoRestart' -Because "Script must declare -NoRestart parameter"
        $paramNames | Should -Contain 'ForceRestart' -Because "Script must declare -ForceRestart parameter"

        $exit100Nodes = $script:ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.ExitStatementAst] -and
            $node.Pipeline.Extent.Text -eq '100'
        }, $true)
        $exit100Nodes.Count | Should -BeGreaterThan 0 -Because "Script must exit with code 100 when restart is scheduled to signal batch wrapper"
    }
    It 'Enforces privilege separation in Remove-StartupEntry (SEC-01)' {
        $removeFunc = $script:ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq 'Remove-StartupEntry'
        }, $true) | Select-Object -First 1

        $removeFunc | Should -Not -BeNullOrEmpty
        $removeFunc.Extent.Text | Should -Match 'HKLM:\\SOFTWARE\\unslop-windows\\StartupBackup'
        $removeFunc.Extent.Text | Should -Match 'HKCU:\\Software\\unslop-windows\\StartupBackup'
        $removeFunc.Extent.Text | Should -Match '\$isHklm\s*=\s*\(\$runKey\s+-match\s+''\^HKLM''\)'
    }

    It 'Isolates user-space OneDrive setup into admin staging directory before Authenticode verification (SEC-02)' {
        $script:ast.Extent.Text | Should -Match 'staging_.*GetRandomFileName'
        $script:ast.Extent.Text | Should -Match 'CN=Microsoft Corporation,'
    }

    It 'Inspects parent directory for ReparsePoint during log initialization (SEC-08)' {
        $script:ast.Extent.Text | Should -Match 'Split-Path -Parent \$logDir'
        $script:ast.Extent.Text | Should -Match '\$env:ProgramData.*unslop-windows\\logs'
    }

    It 'Enforces third-party scope boundary in startup entries (ADR-026)' {
        $forbiddenApps = @('Discord', 'Steam', 'Spotify', 'Chrome', 'EpicGames', 'Battle\.net')
        $startupCalls = $script:ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -eq 'Remove-StartupEntry'
        }, $true)

        foreach ($call in $startupCalls) {
            foreach ($app in $forbiddenApps) {
                $call.Extent.Text | Should -Not -Match "\b$app\b" -Because "Remove-StartupEntry must never target third-party application '$app'"
            }
        }
    }
}
