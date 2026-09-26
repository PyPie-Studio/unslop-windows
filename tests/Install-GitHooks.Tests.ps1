#requires -Version 5.1
<#
.SYNOPSIS
    Pester Unit & Mocking Test Suite for Install-GitHooks.ps1.
    Verifies git environment checks, hook source validation, -Uninstall,
    -InstallPrerequisites, hook synchronization, and -Test gate pipeline execution.
#>

BeforeAll {
    $script:repoRoot = Split-Path -Parent $PSScriptRoot
    $script:targetScript = Join-Path $script:repoRoot "scripts/Install-GitHooks.ps1"

    if (-not (Test-Path $script:targetScript)) {
        throw "Target script not found at: $script:targetScript"
    }

    if (-not (Get-Command Install-Module -ErrorAction SilentlyContinue)) {
        function global:Install-Module { param($Name, $Scope, $Force, $SkipPublisherCheck, $MinimumVersion) }
    }
    if (-not (Get-Command powershell.exe -ErrorAction SilentlyContinue)) {
        function global:powershell.exe { param($NoProfile, $ExecutionPolicy, $File, $Fast) }
    }
}

Describe 'Install-GitHooks: Git & Repository Invariants' -Tag 'Unit', 'GitHooks' {
    It 'Exits with code 1 when git command is not available in PATH' {
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'git' }
        $out = & $script:targetScript *>&1
        $LASTEXITCODE | Should -Be 1
        ($out | Out-String) | Should -Match "ERROR: 'git' command not found in PATH\."
    }

    It 'Exits with code 1 when not inside a git repository' {
        Mock Get-Command { return [pscustomobject]@{ Name = 'git' } } -ParameterFilter { $Name -eq 'git' }
        Mock git {
            $global:LASTEXITCODE = 128
            return "fatal: not a git repository"
        }
        $out = & $script:targetScript *>&1
        $LASTEXITCODE | Should -Be 1
        ($out | Out-String) | Should -Match "ERROR: Not inside a git repository\."
    }

    It 'Exits with code 1 when required source hook files in .githooks are missing' {
        Mock Get-Command { return [pscustomobject]@{ Name = 'git' } } -ParameterFilter { $Name -eq 'git' }
        Mock git {
            $global:LASTEXITCODE = 0
            if ($args -contains '--git-dir') { return ".git" }
            return $null
        }
        Mock Test-Path { return $false } -ParameterFilter { $Path -match '\.githooks' }
        $out = & $script:targetScript *>&1
        $LASTEXITCODE | Should -Be 1
        ($out | Out-String) | Should -Match "ERROR: Hook file not found at:"
    }
}

Describe 'Install-GitHooks: Hook Removal (-Uninstall)' -Tag 'Unit', 'GitHooks' {
    It 'Unsets core.hooksPath and removes hooks from .git/hooks directory' {
        Mock Get-Command { return [pscustomobject]@{ Name = 'git' } } -ParameterFilter { $Name -eq 'git' }
        Mock git {
            $global:LASTEXITCODE = 0
            if ($args -contains '--git-dir') { return ".git" }
            return $null
        }
        Mock Test-Path { return $true }
        Mock Remove-Item { return $null }

        $out = & $script:targetScript -Uninstall *>&1
        ($out | Out-String) | Should -Match "SUCCESS: Git hooks uninstalled\. core\.hooksPath reset to default\."
        Should -Invoke git -Times 2
        Should -Invoke Remove-Item -Times 2
    }
}

Describe 'Install-GitHooks: Prerequisites Setup (-InstallPrerequisites)' -Tag 'Unit', 'GitHooks' {
    It 'Installs Pester 6+ and PSScriptAnalyzer when missing' {
        Mock Get-Command {
            if ($Name -eq 'git') { return [pscustomobject]@{ Name = 'git' } }
            return $ExecutionContext.InvokeCommand.GetCommand($Name, 'All')
        }
        Mock git {
            $global:LASTEXITCODE = 0
            if ($args -contains '--git-dir') { return ".git" }
            if ($args -contains 'core.hooksPath') { return ".githooks" }
            return $null
        }
        Mock Test-Path { return $true }
        Mock Get-Module { return $null }
        Mock Install-Module { return $null }
        Mock Copy-Item { return $null }

        $out = & $script:targetScript -InstallPrerequisites *>&1
        ($out | Out-String) | Should -Match "Checking and installing required testing modules\.\.\."
        ($out | Out-String) | Should -Match "Pester 6\+ installed successfully\."
        ($out | Out-String) | Should -Match "PSScriptAnalyzer installed successfully\."
        Should -Invoke Install-Module -Times 2
    }

    It 'Skips module installation when Pester 6+ and PSScriptAnalyzer are already installed' {
        Mock Get-Command { return [pscustomobject]@{ Name = 'git' } } -ParameterFilter { $Name -eq 'git' }
        Mock git {
            $global:LASTEXITCODE = 0
            if ($args -contains '--git-dir') { return ".git" }
            if ($args -contains 'core.hooksPath') { return ".githooks" }
            return $null
        }
        Mock Test-Path { return $true }
        Mock Get-Module {
            if ($Name -eq 'Pester') {
                return [pscustomobject]@{ Name = 'Pester'; Version = [version]'6.2.0' }
            }
            if ($Name -eq 'PSScriptAnalyzer') {
                return [pscustomobject]@{ Name = 'PSScriptAnalyzer'; Version = [version]'1.25.0' }
            }
            return $null
        }
        Mock Install-Module { return $null }
        Mock Copy-Item { return $null }

        $out = & $script:targetScript -InstallPrerequisites *>&1
        ($out | Out-String) | Should -Match "Pester 6\.2\.0 is already installed\."
        ($out | Out-String) | Should -Match "PSScriptAnalyzer 1\.25\.0 is already installed\."
        Should -Invoke Install-Module -Times 0
    }
}

Describe 'Install-GitHooks: Hook Installation & Fallback Synchronization' -Tag 'Unit', 'GitHooks' {
    It 'Configures core.hooksPath and copies hook scripts to .git/hooks directory' {
        Mock Get-Command { return [pscustomobject]@{ Name = 'git' } } -ParameterFilter { $Name -eq 'git' }
        Mock git {
            $global:LASTEXITCODE = 0
            if ($args -contains '--git-dir') { return ".git" }
            if ($args -contains 'core.hooksPath') { return ".githooks" }
            return $null
        }
        Mock Test-Path { return $true }
        Mock Copy-Item { return $null }

        $out = & $script:targetScript *>&1
        ($out | Out-String) | Should -Match "Configuring git core\.hooksPath to \.githooks\.\.\."
        ($out | Out-String) | Should -Match "Synchronized fallback to: \.git/hooks/pre-commit"
        ($out | Out-String) | Should -Match "Synchronized fallback to: \.git/hooks/pre-push"
        ($out | Out-String) | Should -Match "SUCCESS: Pre-commit and pre-push hooks are active and protecting repository\."
        Should -Invoke Copy-Item -Times 2
    }
}

Describe 'Install-GitHooks: Gate Verification Pipeline (-Test & -Fast)' -Tag 'Unit', 'GitHooks' {
    It 'Executes Test-MasterGate.ps1 in -Fast mode and passes when gate exits 0' {
        Mock Get-Command { return [pscustomobject]@{ Name = $Name } }
        Mock git {
            $global:LASTEXITCODE = 0
            if ($args -contains '--git-dir') { return ".git" }
            if ($args -contains 'core.hooksPath') { return ".githooks" }
            return $null
        }
        Mock Test-Path { return $true }
        Mock Copy-Item { return $null }
        Mock pwsh {
            $global:LASTEXITCODE = 0
            Write-Host "MOCK GATE PASSED"
        }
        Mock powershell.exe {
            $global:LASTEXITCODE = 0
            Write-Host "MOCK GATE PASSED"
        }

        $out = & $script:targetScript -Test -Fast *>&1
        ($out | Out-String) | Should -Match "Hook test verification: PASSED"
    }

    It 'Executes Test-MasterGate.ps1 and propagates non-zero exit code on failure' {
        Mock Get-Command { return [pscustomobject]@{ Name = $Name } }
        Mock git {
            $global:LASTEXITCODE = 0
            if ($args -contains '--git-dir') { return ".git" }
            if ($args -contains 'core.hooksPath') { return ".githooks" }
            return $null
        }
        Mock Test-Path { return $true }
        Mock Copy-Item { return $null }
        Mock pwsh {
            $global:LASTEXITCODE = 42
            Write-Host "MOCK GATE FAILED"
        }
        Mock powershell.exe {
            $global:LASTEXITCODE = 42
            Write-Host "MOCK GATE FAILED"
        }

        $out = & $script:targetScript -Test *>&1
        $LASTEXITCODE | Should -Be 42
        ($out | Out-String) | Should -Match "Hook test verification: FAILED \(Exit Code 42\)"
    }
}
