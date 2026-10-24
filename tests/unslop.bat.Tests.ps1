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
            '-KeepClock', '-KeepSpotify', '-KeepTeams', '-KeepPCManager', '-KeepStoreAutoUpdate',
            '-ClassicContextMenu', '-LeftTaskbar', '-ExcludeWUDrivers', '-KeepEdgeUpdates',
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

Describe 'unslop.bat: Security & Privilege Escalation Defenses' -Tag 'Security', 'Batch' {
    It 'Enforces environment variable quoting on UAC elevation to eliminate single-quote injection (SEC-04)' {
        $script:batContent | Should -Match 'set "UNSLOP_SELF=%~f0"'
        $script:batContent | Should -Match 'Start-Process -FilePath \$env:UNSLOP_SELF'
    }

    It 'Synchronizes -KeepPCManager across custom interactive menu whitelists (SEC-05)' {
        $custom11 = [regex]::Match($script:batContent, '(?s):custom_WIN11\b.*?:custom_run').Value
        $custom10 = [regex]::Match($script:batContent, '(?s):custom_WIN10\b.*?:custom_run').Value

        $custom11 | Should -Match '-KeepPCManager' -Because ":custom_WIN11 must whitelist -KeepPCManager"
        $custom10 | Should -Match '-KeepPCManager' -Because ":custom_WIN10 must whitelist -KeepPCManager"
    }

    It 'Omits -KeepClock from Windows 11 custom interactive whitelist (SEC-06)' {
        $custom11 = [regex]::Match($script:batContent, '(?s):custom_WIN11\b.*?:custom_run').Value
        $custom11 | Should -Not -Match '-KeepClock' -Because ":custom_WIN11 must not whitelist -KeepClock on Windows 11"
    }

    It 'Preserves toggle state and supports reset in interactive menus' {
        $script:batContent | Should -Match ':toggles_reset_WIN11'
        $script:batContent | Should -Match ':toggles_reset_WIN10'
    }
}

Describe 'unslop.bat: CLI Parameter Execution & Safety Enforcement' -Tag 'Batch', 'Execution' {
    It 'Rejects illegal switches with exit code 1 and error output' {
        $out = & cmd.exe /c "call `"$($script:batPath)`" -IllegalSwitch" 2>&1
        $LASTEXITCODE | Should -Be 1
        ($out | Out-String) | Should -Match '\[ERROR\] Unrecognized or illegal parameter switch: "-IllegalSwitch"'
    }

    It 'Rejects simultaneous -Win11 and -Win10 switches with exit code 1' {
        $out = & cmd.exe /c "call `"$($script:batPath)`" -Win11 -Win10" 2>&1
        $LASTEXITCODE | Should -Be 1
        ($out | Out-String) | Should -Match '\[ERROR\] Cannot specify both -Win11 and -Win10 simultaneously\.'
    }

    It 'Rejects -KeepClock when Windows 11 mode is targeted' {
        $out = & cmd.exe /c "call `"$($script:batPath)`" -Win11 -KeepClock" 2>&1
        $LASTEXITCODE | Should -Be 1
        ($out | Out-String) | Should -Match '\[ERROR\] Switch "-KeepClock" is not supported on Windows 11'
    }

    It 'Rejects -ClassicContextMenu and -LeftTaskbar when Windows 10 mode is targeted' {
        $out1 = & cmd.exe /c "call `"$($script:batPath)`" -Win10 -ClassicContextMenu" 2>&1
        $LASTEXITCODE | Should -Be 1
        ($out1 | Out-String) | Should -Match '\[ERROR\] Switch "-ClassicContextMenu" is not supported on Windows 10\.'

        $out2 = & cmd.exe /c "call `"$($script:batPath)`" -Win10 -LeftTaskbar" 2>&1
        $LASTEXITCODE | Should -Be 1
        ($out2 | Out-String) | Should -Match '\[ERROR\] Switch "-LeftTaskbar" is not supported on Windows 10\.'
    }

    It 'Fails with exit code 1 when required companion scripts are missing' {
        $tempDir = Join-Path $env:TEMP ("unslop_bat_test_" + [System.Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        try {
            $tempBat = Join-Path $tempDir "unslop.bat"
            Copy-Item -Path $script:batPath -Destination $tempBat
            $out = & cmd.exe /c "call `"$tempBat`" -DryRun" 2>&1
            $LASTEXITCODE | Should -Be 1
            ($out | Out-String) | Should -Match '\[ERROR\] MISSING REQUIRED SCRIPTS'
        } finally {
            if (Test-Path $tempDir) {
                Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
