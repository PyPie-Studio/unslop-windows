#requires -Version 5.1
<#
.SYNOPSIS
    Pester Unit Test Suite for scripts/Test-Coverage.ps1.
    Verifies AST validity, parameter bindings, mutual exclusivity guards,
    ValidateRange attributes, and markdown report generation invariants.
#>

BeforeAll {
    $script:repoRoot = Split-Path -Parent $PSScriptRoot
    $script:covScript = Join-Path $script:repoRoot "scripts\Test-Coverage.ps1"

    if (-not (Test-Path -LiteralPath $script:covScript)) {
        throw "Target script not found at: $script:covScript"
    }

    $script:covContent = Get-Content -Path $script:covScript -Raw
    $parseErrors = $null
    $tokens = $null
    $script:ast = [System.Management.Automation.Language.Parser]::ParseInput($script:covContent, [ref]$tokens, [ref]$parseErrors)
    $script:parseErrors = $parseErrors
}

Describe 'Test-Coverage: AST & Static Structure Invariants' -Tag 'Unit', 'Coverage' {
    It 'Target script exists and parses clean with 0 syntax errors' {
        Test-Path -LiteralPath $script:covScript | Should -Be $true
        $script:parseErrors | Should -BeNullOrEmpty
    }

    It 'Declares [CmdletBinding()] attribute' {
        $script:ast.ParamBlock.Attributes.TypeName.Name | Should -Contain 'CmdletBinding'
    }

    It 'Declares all expected parameters' {
        $paramNames = $script:ast.ParamBlock.Parameters.Name.VariablePath.UserPath
        $expectedParams = @(
            'Detailed',
            'ReportPath',
            'NoMarkdown',
            'Threshold',
            'Win11',
            'Win10',
            'Both',
            'SkipTest',
            'CoverageResultsPath'
        )

        foreach ($expected in $expectedParams) {
            $paramNames | Should -Contain $expected -Because "Parameter -$expected must be declared in Test-Coverage.ps1"
        }
    }

    It 'Declares appropriate types for switch, double, and string parameters' {
        $params = $script:ast.ParamBlock.Parameters
        $switchParams = @('Detailed', 'NoMarkdown', 'Win11', 'Win10', 'Both', 'SkipTest')
        $stringParams = @('ReportPath', 'CoverageResultsPath')
        $doubleParams = @('Threshold')

        foreach ($p in $params) {
            $name = $p.Name.VariablePath.UserPath
            if ($name -in $switchParams) {
                $p.StaticType.Name | Should -Be 'SwitchParameter' -Because "-$name should be [switch]"
            } elseif ($name -in $stringParams) {
                $p.StaticType.Name | Should -Be 'String' -Because "-$name should be [string]"
            } elseif ($name -in $doubleParams) {
                $p.StaticType.Name | Should -Be 'Double' -Because "-$name should be [double]"
            }
        }
    }

    It 'Threshold defaults to 0 and declares ValidateRange(0.0, 100.0)' {
        $threshParam = $script:ast.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Threshold' }
        $threshParam | Should -Not -BeNullOrEmpty
        $threshParam.DefaultValue.Extent.Text | Should -Be '0.0'
        $rangeAttr = $threshParam.Attributes | Where-Object { $_.TypeName.Name -eq 'ValidateRange' }
        $rangeAttr | Should -Not -BeNullOrEmpty
    }
}

Describe 'Test-Coverage: Target Discovery & Script Roles' -Tag 'Unit', 'Coverage' {
    It 'Monitors all core engines and support utilities' {
        $script:covContent | Should -Match 'unslop-win11\.ps1'
        $script:covContent | Should -Match 'unslop-win10\.ps1'
        $script:covContent | Should -Match 'Measure-SystemState\.ps1'
        $script:covContent | Should -Match 'Install-GitHooks\.ps1'
        $script:covContent | Should -Match 'Test-MasterGate\.ps1'
        $script:covContent | Should -Match 'Test-Coverage\.ps1'
    }

    It 'Defines role mapping for presentation UI' {
        $script:covContent | Should -Match 'roleMap\s*='
        $script:covContent | Should -Match 'Windows 11 Debloat & Hardening Engine'
        $script:covContent | Should -Match 'Windows 10 Debloat & Hardening Engine'
        $script:covContent | Should -Match 'System State & Benchmark Telemetry'
        $script:covContent | Should -Match 'Git Hooks & Environment Setup'
        $script:covContent | Should -Match 'Master Quality Gate & CI Pipeline'
        $script:covContent | Should -Match 'Code Coverage Profiler & Reporter'
    }
}

Describe 'Test-Coverage: Execution & Exit Code Contracts' -Tag 'Unit', 'Coverage' {
    It 'Enforces mutual exclusivity between -Win11 and -Win10' {
        $proc = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$script:covScript`"", "-Win11", "-Win10" -NoNewWindow -PassThru -Wait -RedirectStandardError "nul"
        $proc.ExitCode | Should -Be 1
    }

    It 'Enforces mutual exclusivity when -Both is combined with -Win11 or -Win10' {
        $proc1 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$script:covScript`"", "-Both", "-Win11" -NoNewWindow -PassThru -Wait -RedirectStandardError "nul"
        $proc1.ExitCode | Should -Be 1

        $proc2 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$script:covScript`"", "-Both", "-Win10" -NoNewWindow -PassThru -Wait -RedirectStandardError "nul"
        $proc2.ExitCode | Should -Be 1
    }

    It 'Enforces ValidateRange when -Threshold is negative' {
        $proc = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$script:covScript`"", "-Threshold", "-5" -NoNewWindow -PassThru -Wait -RedirectStandardError "nul"
        $proc.ExitCode | Should -Be 1
    }

    It 'Enforces ValidateRange when -Threshold exceeds 100' {
        $proc = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$script:covScript`"", "-Threshold", "105" -NoNewWindow -PassThru -Wait -RedirectStandardError "nul"
        $proc.ExitCode | Should -Be 1
    }
}

Describe 'Test-Coverage: Markdown Generation Structure' -Tag 'Unit', 'Coverage' {
    It 'Generates markdown header, tables, and safe-tier methodology' {
        $script:covContent | Should -Match '# unslop-windows: Test Coverage & Verification Report'
        $script:covContent | Should -Match '## 1\. Summary Metrics'
        $script:covContent | Should -Match '## 2\. Per-Script Coverage Breakdown'
        $script:covContent | Should -Match '## 3\. Safe-Tier Verification Methodology'
        $script:covContent | Should -Match 'yyyy-MM-dd hh:mm tt'
    }
}
