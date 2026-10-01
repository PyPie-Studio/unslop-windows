#requires -Version 5.1
<#
.SYNOPSIS
    Pester Unit & Integration Test Suite for unslop.bat.
    Verifies batch script launcher static structure, parameter whitelist validation,
    missing script dependencies guard, anti-injection mechanisms, and CLI passthrough routing logic.
#>

BeforeAll {
    $script:repoRoot = Split-Path -Parent $PSScriptRoot
    $script:batPath = Join-Path $script:repoRoot "unslop.bat"

    if (-not (Test-Path $script:batPath)) {
        throw "Target batch file not found at: $script:batPath"
    }

    $script:batContent = Get-Content -Path $script:batPath -Raw
}

Describe 'unslop.bat: Static Integrity & Syntax Invariants' -Tag 'Unit', 'Batch' {
    It 'File exists and is non-empty' {
        Test-Path $script:batPath | Should -Be $true
        $script:batContent.Length | Should -BeGreaterThan 0
    }

    It 'Enforces CRLF line endings (no naked LF bytes)' {
        $bytes = [System.IO.File]::ReadAllBytes($script:batPath)
        $hasNakedLf = $false
        for ($i = 0; $i -lt $bytes.Length; $i++) {
            if ($bytes[$i] -eq 10) { # LF
                if ($i -eq 0 -or $bytes[$i - 1] -ne 13) { # Not preceded by CR
                    $hasNakedLf = $true
                    break
                }
            }
        }
        $hasNakedLf | Should -Be $false -Because "unslop.bat must use CRLF line endings for Windows cmd.exe compatibility"
    }

    It 'Contains required script existence guard checks' {
        $script:batContent | Should -Match 'if not exist "%~dp0unslop-win11\.ps1" set "MISSING=1"'
        $script:batContent | Should -Match 'if not exist "%~dp0unslop-win10\.ps1" set "MISSING=1"'
    }

    It 'Contains mandatory CLI parameter switches in whitelist loop' {
        $expectedSwitches = @(
            '-Undo', '-Restore', '-DryRun', '-WhatIf', '-KeepXbox', '-KeepOneDrive',
            '-KeepTodos', '-KeepSysMain', '-KeepSearch', '-KeepPhoneLink', '-KeepMail',
            '-KeepClock', '-KeepSpotify', '-KeepTeams', '-KeepStoreAutoUpdate',
            '-ClassicContextMenu', '-LeftTaskbar', '-ExcludeWUDrivers',
            '-KeepDefenderDefaults', '-NoRestart', '-ForceRestart', '-RunDirect',
            '-FromMenu', '-Win11', '-Win10', '-SkipBuildCheck'
        )

        foreach ($switch in $expectedSwitches) {
            $pattern = [regex]::Escape($switch)
            $script:batContent | Should -Match $pattern -Because "unslop.bat switch whitelist must include $switch"
        }
    }

    It 'Configures launcher title and eco-guard header' {
        $script:batContent | Should -Match 'title unslop-windows Launcher'
        $script:batContent | Should -Match '@echo off'
    }
}

Describe 'unslop.bat: Argument Parsing & Whitelist Validation' -Tag 'Unit', 'Batch' {
    BeforeAll {
        # Extract whitelist strings from unslop.bat for invariant testing
        $script:allowedSwitches = @()
        $regexMatches = [regex]::Matches($script:batContent, 'for %%V in \(([^)]+)\)')
        foreach ($m in $regexMatches) {
            $switches = $m.Groups[1].Value -split '\s+' | Where-Object { $_ }
            $script:allowedSwitches += $switches
        }
        $script:allowedSwitches = $script:allowedSwitches | Select-Object -Unique
    }

    It 'Extracts allowed switches array from batch source' {
        $script:allowedSwitches.Count | Should -BeGreaterThan 10
    }

    It 'Rejects unauthorized parameters or injection tokens' {
        $illegalTokens = @(';calc.exe', '&dir', '|whoami', '-InvalidSwitch', 'http://malicious.url', '--help', 'cmd.exe', 'powershell')
        foreach ($token in $illegalTokens) {
            $script:allowedSwitches | Should -Not -Contain $token
        }
    }

    It 'Defines OS routing flags (-Win10 and -Win11)' {
        $script:allowedSwitches | Should -Contain '-Win10'
        $script:allowedSwitches | Should -Contain '-Win11'
    }
}

Describe 'unslop.bat: Interactive Menu Structure' -Tag 'Unit', 'Batch' {
    It 'Defines main OS selection menus (:menu_WIN11 and :menu_WIN10)' {
        $script:batContent | Should -Match ':menu_WIN11'
        $script:batContent | Should -Match ':menu_WIN10'
    }

    It 'Defines interactive toggle sub-menus (:toggles_WIN11 and :toggles_WIN10)' {
        $script:batContent | Should -Match ':toggles_WIN11'
        $script:batContent | Should -Match ':toggles_WIN10'
    }

    It 'Defines custom CLI flag entry sub-menus (:custom_WIN11 and :custom_WIN10)' {
        $script:batContent | Should -Match ':custom_WIN11'
        $script:batContent | Should -Match ':custom_WIN10'
    }

    It 'Handles reboot exit code 100 gracefully without pausing' {
        $script:batContent | Should -Match 'if !errorlevel! equ 100 exit /b 0'
    }
}
