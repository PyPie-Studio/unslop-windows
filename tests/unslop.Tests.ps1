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
                Status = "Running"
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
                Status = "Stopped"
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

    Context 'Remove-StartupEntry' {
        It 'Debloat Mode: Archives startup entry to backup key and removes from Run' {
            $mockProps = [PSCustomObject]@{
                Discord = "C:\Users\test\AppData\Local\Discord\app.exe"
            }
            Mock -CommandName Get-ItemProperty -MockWith { $mockProps }
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Set-ItemProperty -MockWith { }
            Mock -CommandName Remove-ItemProperty -MockWith { }

            Remove-StartupEntry -pattern "Discord" -runKeys @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run")

            Should -Invoke -CommandName Set-ItemProperty -Times 1 -ParameterFilter {
                $Path -match "StartupBackup" -and $Name -eq "Discord"
            }
            Should -Invoke -CommandName Remove-ItemProperty -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -and $Name -eq "Discord"
            }
        }

        It 'Undo Mode: Restores archived startup entry from backup key to Run' {
            $mockBackupProps = [PSCustomObject]@{
                Discord = "C:\Users\test\AppData\Local\Discord\app.exe"
            }
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Get-ItemProperty -MockWith { $mockBackupProps }
            Mock -CommandName Set-ItemProperty -MockWith { }
            Mock -CommandName Remove-ItemProperty -MockWith { }

            Remove-StartupEntry -pattern "Discord" -runKeys @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run") -Undo

            Should -Invoke -CommandName Set-ItemProperty -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -and $Name -eq "Discord"
            }
            Should -Invoke -CommandName Remove-ItemProperty -Times 1 -ParameterFilter {
                $Path -match "StartupBackup" -and $Name -eq "Discord"
            }
        }

        It 'Dry-Run Mode: Performs zero mutating calls during startup management' {
            $mockProps = [PSCustomObject]@{
                Discord = "C:\Users\test\AppData\Local\Discord\app.exe"
            }
            Mock -CommandName Get-ItemProperty -MockWith { $mockProps }
            Mock -CommandName Set-ItemProperty -MockWith { }
            Mock -CommandName Remove-ItemProperty -MockWith { }

            Remove-StartupEntry -pattern "Discord" -runKeys @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run") -DryRun

            Should -Invoke -CommandName Set-ItemProperty -Times 0
            Should -Invoke -CommandName Remove-ItemProperty -Times 0
        }
    }

    Context 'Failure Honesty & Negative Error Trapping' {
        It 'Set-RegDwordSafe traps exceptions, increments FailCount, and emits FAILED log' {
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Set-ItemProperty -MockWith { throw "Access to registry is denied" }
            $global:FailCount = 0
            $script:log = @()

            Set-RegDwordSafe -path "HKLM:\SOFTWARE\Policies\Test" -name "TestVal" -debloatValue 1 -undoValue 0

            $global:FailCount | Should -Be 1
            ($script:log | Where-Object { $_ -match "FAILED: Could not set TestVal in HKLM:\\SOFTWARE\\Policies\\Test" }).Count | Should -BeGreaterThan 0
        }

        It 'Set-SvcState traps exceptions, increments FailCount, and emits FAILED log' {
            $mockSvc = [PSCustomObject]@{ Status = "Running" }
            Mock -CommandName Get-Service -MockWith { $mockSvc }
            Mock -CommandName Stop-Service -MockWith { throw "Service cannot be stopped" }
            $global:FailCount = 0
            $script:log = @()

            Set-SvcState -name "TestSvc" -desc "Test service"

            $global:FailCount | Should -Be 1
            ($script:log | Where-Object { $_ -match "FAILED: Could not disable service TestSvc" }).Count | Should -BeGreaterThan 0
        }

        It 'Set-TaskState traps exceptions, increments FailCount, and emits FAILED log' {
            $mockTask = [PSCustomObject]@{ TaskName = "TestTask" }
            Mock -CommandName Get-ScheduledTask -MockWith { $mockTask }
            Mock -CommandName Disable-ScheduledTask -MockWith { throw "Task operation failed" }
            $global:FailCount = 0
            $script:log = @()

            Set-TaskState -path "\TestPath\" -name "TestTask"

            $global:FailCount | Should -Be 1
            ($script:log | Where-Object { $_ -match "FAILED: Could not disable task TestTask" }).Count | Should -BeGreaterThan 0
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

Describe 'unslop-windows: 100% Symmetrical Restoration Contract (AST Parity)' -Tag 'Unit', 'Static', 'Symmetry' {
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

        $regCalls.Count | Should -BeGreaterThan 30 -Because "Script must contain registry debloat operations"

        foreach ($call in $regCalls) {
            $cmdElements = $call.CommandElements
            $cmdText = $call.Extent.Text

            # Extract parameter values by name or positional order
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
        $approvedRegHelpers = @('Set-RegDwordSafe', 'Set-ConsentCapability', 'Remove-StartupEntry')
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
                        $isApprovedException = ($node.Extent.Text -match 'classicMenuPath') -or ($node.Extent.Text -match 'ExcludeWUDriversInQualityUpdate')
                        return (-not $isApprovedException)
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

    It 'Core engine helper functions maintain strict bidirectional symmetry' {
        $functions = $script:ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
        }, $true)

        $funcNames = $functions | ForEach-Object { $_.Name }
        $funcNames | Should -Contain 'Set-RegDwordSafe'
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
}

Describe 'unslop-windows: Security & Privilege Boundary Invariants' -Tag 'Security', 'Unit' {
    It 'Enforces Authenticode signature verification on user-space executables' {
        $setupCalls = $script:ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -eq 'Get-AuthenticodeSignature'
        }, $true)

        $setupCalls.Count | Should -BeGreaterThan 0 -Because "Script must enforce Authenticode signature verification on user-space executables"
    }

    It 'Log path resolution protects against reparse point / symlink redirection' {
        $reparseChecks = $script:ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.MemberExpressionAst] -and
            $node.Member.Extent.Text -eq 'ReparsePoint'
        }, $true)

        $reparseChecks.Count | Should -BeGreaterThan 0 -Because "Log initialization must inspect directory attributes for ReparsePoint to prevent symlink attacks"
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
            'Microsoft.WindowsTerminal',
            'MicrosoftWindows.Client.Photon',
            'MicrosoftWindows.Client.CoreAI',
            'MicrosoftWindows.UndockedDevKit'
        )

        foreach ($pkg in $nonRemovables) {
            $script:ast.Extent.Text | Should -Not -Match "`"$([regex]::Escape($pkg))`"" -Because "$pkg is a NonRemovable or untouchable system component and must not be in bloatApps"
        }
    }

    It 'Never references unmounted HKCR drive in registry paths' {
        $script:ast.Extent.Text | Should -Not -Match 'HKCR:\\' -Because "PowerShell does not mount HKCR: by default; use HKLM:\SOFTWARE\Classes or HKCU:\Software\Classes"
    }

    It 'Disables Widgets via official GPO AllowNewsAndInterests policy rather than UCPD-blocked TaskbarDa' {
        $script:ast.Extent.Text | Should -Match 'AllowNewsAndInterests' -Because "Widgets must be disabled via HKLM Dsh policy to prevent UCPD UnauthorizedAccessException"
    }

    It 'Does not include SYSTEM-only SdbinstMergeDbTask in debloat tasks' {
        $script:ast.Extent.Text | Should -Not -Match 'SdbinstMergeDbTask' -Because "SdbinstMergeDbTask is ACL-restricted to SYSTEM and is non-telemetry"
    }
}
