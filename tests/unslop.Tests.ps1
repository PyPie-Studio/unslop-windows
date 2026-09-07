#requires -Version 5.1
<#
.SYNOPSIS
    Pester Unit & Mocking Test Suite for unslop-windows.
    Tests engine functions, dot-sourcing isolation, mock-intercepted mutations,
    parameter switches, and the non-elevated security contract.
#>

BeforeAll {
    $script:repoRoot = Split-Path -Parent $PSScriptRoot
    $script:targetScript = Join-Path $script:repoRoot "unslop.ps1"

    if (-not (Test-Path $script:targetScript)) {
        throw "Target engine script not found at: $script:targetScript"
    }

    # Resolve preferred PowerShell CLI executable
    $script:psCli = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell.exe" }

    # Dot-source engine to export helper functions into test session
    . $script:targetScript
}

Describe 'unslop-windows: Engine Architecture & Dot-Sourcing' -Tag 'Unit', 'Core' {
    It 'Dot-sourcing exports all core engine functions into caller scope' {
        $expectedFunctions = @(
            'Log',
            'Set-SvcState',
            'Set-TaskState',
            'Set-RegDwordSafe',
            'Set-ConsentCapability',
            'Remove-StartupEntry'
        )

        foreach ($fn in $expectedFunctions) {
            $cmd = Get-Command -Name $fn -ErrorAction SilentlyContinue
            $cmd | Should -Not -BeNullOrEmpty -Because "Function '$fn' must be exported when unslop.ps1 is dot-sourced"
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

Describe 'unslop-windows: Helper Function Unit Tests' -Tag 'Unit', 'Helpers' {
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

        It 'Dry-Run Mode: Performs zero mutating registry calls' {
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Set-ItemProperty -MockWith { }
            Mock -CommandName Remove-ItemProperty -MockWith { }
            Mock -CommandName New-Item -MockWith { }

            # Test debloat dry-run
            Set-RegDwordSafe -path "HKLM:\SOFTWARE\Policies\Test" -name "TestKey" -debloatValue 1 -undoValue 0 -DryRun

            # Test undo dry-run with removeOnUndo
            Set-RegDwordSafe -path "HKLM:\SOFTWARE\Policies\Test" -name "TestKey" -debloatValue 1 -undoValue 0 -removeOnUndo $true -Undo -DryRun

            Should -Invoke -CommandName Set-ItemProperty -Times 0
            Should -Invoke -CommandName Remove-ItemProperty -Times 0
            Should -Invoke -CommandName New-Item -Times 0
        }
    }

    Context 'Set-SvcState' {
        It 'Debloat Mode: Stops running service and disables startup' {
            $mockRunningService = [PSCustomObject]@{
                Name   = "DiagTrack"
                Status = [System.ServiceProcess.ServiceControllerStatus]::Running
            }
            Mock -CommandName Get-Service -MockWith { $mockRunningService }
            Mock -CommandName Stop-Service -MockWith { }
            Mock -CommandName Set-Service -MockWith { }

            Set-SvcState "DiagTrack" "Diagnostics Tracking"

            Should -Invoke -CommandName Stop-Service -Times 1 -ParameterFilter { $Name -eq "DiagTrack" }
            Should -Invoke -CommandName Set-Service -Times 1 -ParameterFilter { $Name -eq "DiagTrack" -and $StartupType -eq "Disabled" }
        }

        It 'Undo Mode: Re-enables service with specified StartupType and starts it' {
            $mockStoppedService = [PSCustomObject]@{
                Name   = "DiagTrack"
                Status = [System.ServiceProcess.ServiceControllerStatus]::Stopped
            }
            Mock -CommandName Get-Service -MockWith { $mockStoppedService }
            Mock -CommandName Set-Service -MockWith { }
            Mock -CommandName Start-Service -MockWith { }

            Set-SvcState "DiagTrack" "Diagnostics Tracking" "Automatic" -Undo

            Should -Invoke -CommandName Set-Service -Times 1 -ParameterFilter { $Name -eq "DiagTrack" -and $StartupType -eq "Automatic" }
            Should -Invoke -CommandName Start-Service -Times 1 -ParameterFilter { $Name -eq "DiagTrack" }
        }

        It 'Missing Service: Gracefully skips non-existent services without invoking mutating cmdlets' {
            Mock -CommandName Get-Service -MockWith { $null }
            Mock -CommandName Stop-Service -MockWith { }
            Mock -CommandName Set-Service -MockWith { }
            Mock -CommandName Start-Service -MockWith { }

            Set-SvcState "NonExistentService" "Testing missing service"

            Should -Invoke -CommandName Stop-Service -Times 0
            Should -Invoke -CommandName Set-Service -Times 0
            Should -Invoke -CommandName Start-Service -Times 0
        }
    }

    Context 'Set-TaskState' {
        It 'Debloat Mode: Disables scheduled task if present' {
            $mockTask = [PSCustomObject]@{
                TaskName = "Consolidator"
                TaskPath = "\Microsoft\Windows\Customer Experience Improvement Program\"
            }
            Mock -CommandName Get-ScheduledTask -MockWith { $mockTask }
            Mock -CommandName Disable-ScheduledTask -MockWith { }
            Mock -CommandName Enable-ScheduledTask -MockWith { }

            Set-TaskState "\Microsoft\Windows\Customer Experience Improvement Program\" "Consolidator"

            Should -Invoke -CommandName Disable-ScheduledTask -Times 1 -ParameterFilter {
                $TaskPath -eq "\Microsoft\Windows\Customer Experience Improvement Program\" -and $TaskName -eq "Consolidator"
            }
            Should -Invoke -CommandName Enable-ScheduledTask -Times 0
        }

        It 'Undo Mode: Enables scheduled task if present' {
            $mockTask = [PSCustomObject]@{
                TaskName = "Consolidator"
                TaskPath = "\Microsoft\Windows\Customer Experience Improvement Program\"
            }
            Mock -CommandName Get-ScheduledTask -MockWith { $mockTask }
            Mock -CommandName Disable-ScheduledTask -MockWith { }
            Mock -CommandName Enable-ScheduledTask -MockWith { }

            Set-TaskState "\Microsoft\Windows\Customer Experience Improvement Program\" "Consolidator" -Undo

            Should -Invoke -CommandName Enable-ScheduledTask -Times 1 -ParameterFilter {
                $TaskPath -eq "\Microsoft\Windows\Customer Experience Improvement Program\" -and $TaskName -eq "Consolidator"
            }
            Should -Invoke -CommandName Disable-ScheduledTask -Times 0
        }
    }

    Context 'Set-ConsentCapability' {
        It 'Debloat Mode: Sets capability consent to Deny' {
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Set-ItemProperty -MockWith { }

            Set-ConsentCapability "foregroundTextAccess" "Screen text analysis" "Deny" "Allow"

            Should -Invoke -CommandName Set-ItemProperty -Times 1 -ParameterFilter {
                $Path -match "ConsentStore\\foregroundTextAccess" -and
                $Name -eq "Value" -and
                $Value -eq "Deny"
            }
        }

        It 'Undo Mode: Restores capability consent to Allow' {
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Set-ItemProperty -MockWith { }

            Set-ConsentCapability "foregroundTextAccess" "Screen text analysis" "Deny" "Allow" -Undo

            Should -Invoke -CommandName Set-ItemProperty -Times 1 -ParameterFilter {
                $Path -match "ConsentStore\\foregroundTextAccess" -and
                $Name -eq "Value" -and
                $Value -eq "Allow"
            }
        }
    }
}

Describe 'unslop-windows: Parameter Flags & Whitelist Invariants' -Tag 'Integration', 'CLI' {
    It 'Non-elevated run without -DryRun exits with code 1' {
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin) {
            $proc = Start-Process -FilePath $script:psCli -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$($script:targetScript)`"" -Wait -PassThru -WindowStyle Hidden
            $proc.ExitCode | Should -Be 1 -Because "Execution without admin privileges must exit with code 1"
        } else {
            Set-ItResult -Skipped -Because "Current shell is already elevated; skipping mutation test"
        }
    }

    It 'Non-elevated run with -DryRun exits with code 0' {
        $output = & $script:psCli -NoProfile -ExecutionPolicy Bypass -File $script:targetScript -DryRun 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -match "UNSLOP-WINDOWS: DEBLOAT & HARDEN COMPLETE").Length | Should -BeGreaterThan 0
    }

    It '-KeepXbox retains Xbox gaming services and preserves untouchable whitelist' {
        $output = & $script:psCli -NoProfile -ExecutionPolicy Bypass -File $script:targetScript -DryRun -KeepXbox 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -match "Gaming & Xbox services retained \(-KeepXbox enabled\)").Length | Should -BeGreaterThan 0
        ($output -match "\[WOULD DE-PROVISION\]:.*Microsoft\.GamingApp").Length | Should -Be 0
        ($output -match "\[WOULD DE-PROVISION\]:.*Microsoft\.XboxIdentityProvider").Length | Should -Be 0 -Because "XboxIdentityProvider is on the untouchable whitelist"
    }

    It '-KeepOneDrive retains OneDrive and skips file sync killswitch' {
        $output = & $script:psCli -NoProfile -ExecutionPolicy Bypass -File $script:targetScript -DryRun -KeepOneDrive 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -match "OneDrive retained \(-KeepOneDrive enabled\)").Length | Should -BeGreaterThan 0
        ($output -match "\[WOULD UNINSTALL\]: OneDrive").Length | Should -Be 0
        ($output -match "DisableFileSyncNGSC").Length | Should -Be 0
    }
}
