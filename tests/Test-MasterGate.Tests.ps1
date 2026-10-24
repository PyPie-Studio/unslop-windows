#requires -Version 5.1
<#
.SYNOPSIS
    Pester Unit Test Suite for scripts/Test-MasterGate.ps1.
    Verifies AST validity, parameter bindings, mutual exclusivity guards,
    exclusion regex coverage, test suite registration parity, and CRLF / conflict marker scanner logic.
#>

BeforeAll {
    $script:repoRoot = Split-Path -Parent $PSScriptRoot
    $script:gateScript = Join-Path $script:repoRoot "scripts\Test-MasterGate.ps1"

    if (-not (Test-Path $script:gateScript)) {
        throw "Target script not found at: $script:gateScript"
    }

    $script:gateContent = Get-Content -Path $script:gateScript -Raw
    $parseErrors = $null
    $tokens = $null
    $script:ast = [System.Management.Automation.Language.Parser]::ParseInput($script:gateContent, [ref]$tokens, [ref]$parseErrors)
    $script:parseErrors = $parseErrors
}

Describe 'Test-MasterGate: AST & Static Structure Invariants' -Tag 'Unit', 'MasterGate' {
    It 'Target script exists and parses clean with 0 syntax errors' {
        Test-Path $script:gateScript | Should -Be $true
        $script:parseErrors | Should -BeNullOrEmpty
    }

    It 'Declares [CmdletBinding()] attribute' {
        $script:ast.ParamBlock.Attributes.TypeName.Name | Should -Contain 'CmdletBinding'
    }

    It 'Declares all expected parameters' {
        $paramNames = $script:ast.ParamBlock.Parameters.Name.VariablePath.UserPath
        $expectedParams = @(
            'Fast',
            'SkipAnalyzer',
            'SkipUnitTests',
            'IncludeIntegration',
            'Strict',
            'Win11',
            'Win10',
            'Both',
            'SkipBuildCheck',
            'LintDocs',
            'TestResultsPath',
            'CodeCoveragePath'
        )

        foreach ($expected in $expectedParams) {
            $paramNames | Should -Contain $expected -Because "Parameter -$expected must be declared in Test-MasterGate.ps1"
        }
    }

    It 'Declares appropriate types for switch and string parameters' {
        $params = $script:ast.ParamBlock.Parameters
        $switchParams = @('Fast', 'SkipAnalyzer', 'SkipUnitTests', 'IncludeIntegration', 'Strict', 'Win11', 'Win10', 'Both', 'SkipBuildCheck', 'LintDocs')
        $stringParams = @('TestResultsPath', 'CodeCoveragePath')

        foreach ($p in $params) {
            $name = $p.Name.VariablePath.UserPath
            if ($name -in $switchParams) {
                $p.StaticType.Name | Should -Be 'SwitchParameter' -Because "-$name should be [switch]"
            } elseif ($name -in $stringParams) {
                $p.StaticType.Name | Should -Be 'String' -Because "-$name should be [string]"
            }
        }
    }
}

Describe 'Test-MasterGate: Exclusion Regex & Scanner Invariants' -Tag 'Unit', 'MasterGate' {
    It 'Excludes all untracked, external, and internal directories in AST verification' {
        $script:gateContent | Should -Match 'Where-Object\s*\{\s*\$_\.FullName\s+-notmatch\s+''\\\\\(logs\|\\\.git\|videos\|graphify-out\|test-results\|\\\.agents\|node_modules\)\\\\'''
    }

    It 'Excludes all untracked, external, and internal directories in PSScriptAnalyzer verification' {
        $script:gateContent | Should -Match 'Where-Object\s*\{\s*\$_\.ScriptPath\s+-notmatch\s+''\\\\\(logs\|\\\.git\|videos\|graphify-out\|test-results\|\\\.agents\|node_modules\)\\\\'''
    }

    It 'Excludes all untracked, external, and internal directories in merge conflict verification' {
        # Validates that textFiles scanner also excludes all untracked directories
        $matchesFound = [regex]::Matches($script:gateContent, 'Where-Object\s*\{\s*\$_\.FullName\s+-notmatch\s+''\\\\\(logs\|\\\.git\|videos\|graphify-out\|test-results\|\\\.agents\|node_modules\)\\\\''')
        $matchesFound.Count | Should -Be 2 -Because "Both AST script scan and conflict marker text scan must use the hardened exclusion regex"
    }

    It 'Hardened exclusion regex matches designated folders correctly' {
        $pattern = '\\(logs|\.git|videos|graphify-out|test-results|\.agents|node_modules)\\'
        "C:\repo\logs\run.log" | Should -Match $pattern
        "C:\repo\.git\HEAD" | Should -Match $pattern
        "C:\repo\videos\promo.mp4" | Should -Match $pattern
        "C:\repo\graphify-out\report.md" | Should -Match $pattern
        "C:\repo\test-results\pester.xml" | Should -Match $pattern
        "C:\repo\.agents\skills\test.md" | Should -Match $pattern
        "C:\repo\node_modules\bin\cli.js" | Should -Match $pattern

        # Must NOT match tracked source directories
        "C:\repo\scripts\Test-MasterGate.ps1" | Should -Not -Match $pattern
        "C:\repo\tests\unslop-win11.Tests.ps1" | Should -Not -Match $pattern
        "C:\repo\docs\decisions.md" | Should -Not -Match $pattern
        "C:\repo\unslop-win11.ps1" | Should -Not -Match $pattern
    }
}

Describe 'Test-MasterGate: Test Registration Parity' -Tag 'Unit', 'MasterGate' {
    It 'Registers all repository test suites for execution in Step 4/7' {
        $script:gateContent | Should -Match 'tests\\unslop\.bat\.Tests\.ps1'
        $script:gateContent | Should -Match 'tests\\Install-GitHooks\.Tests\.ps1'
        $script:gateContent | Should -Match 'tests\\Measure-SystemState\.Tests\.ps1'
        $script:gateContent | Should -Match 'tests\\Test-MasterGate\.Tests\.ps1'
    }
}

Describe 'Test-MasterGate: Scanner Logic Algorithms' -Tag 'Unit', 'MasterGate' {
    It 'CRLF algorithm detects naked LF line endings correctly' {
        # CRLF buffer: OK
        $crlfBytes = [byte[]]@(65, 13, 10, 66, 13, 10) # "A\r\nB\r\n"
        $hasNakedLf = $false
        for ($i = 0; $i -lt $crlfBytes.Length; $i++) {
            if ($crlfBytes[$i] -eq 10) {
                if ($i -eq 0 -or $crlfBytes[$i - 1] -ne 13) {
                    $hasNakedLf = $true
                    break
                }
            }
        }
        $hasNakedLf | Should -Be $false

        # Naked LF buffer: FAILS
        $lfBytes = [byte[]]@(65, 10, 66, 10) # "A\nB\n"
        $hasNakedLf2 = $false
        for ($i = 0; $i -lt $lfBytes.Length; $i++) {
            if ($lfBytes[$i] -eq 10) {
                if ($i -eq 0 -or $lfBytes[$i - 1] -ne 13) {
                    $hasNakedLf2 = $true
                    break
                }
            }
        }
        $hasNakedLf2 | Should -Be $true
    }

    It 'Merge conflict detector matches Git conflict markers and ignores regular code' {
        $cleanContent = "function Test { param(`$x) return `$x * 2 }"
        $conflictContent1 = "<<<<<<< HEAD`nparam(`$x)`n======="
        $conflictContent2 = ">>>>>>> main`n"

        $isClean = ($cleanContent -match '(?m)^<{7}\s' -or $cleanContent -match '(?m)^={7}$' -or $cleanContent -match '(?m)^>{7}\s')
        $hasConflict1 = ($conflictContent1 -match '(?m)^<{7}\s' -or $conflictContent1 -match '(?m)^={7}$' -or $conflictContent1 -match '(?m)^>{7}\s')
        $hasConflict2 = ($conflictContent2 -match '(?m)^<{7}\s' -or $conflictContent2 -match '(?m)^={7}$' -or $conflictContent2 -match '(?m)^>{7}\s')

        $isClean | Should -Be $false
        $hasConflict1 | Should -Be $true
        $hasConflict2 | Should -Be $true
    }

    It 'Workflow integrity scanner detects dynamic shell expressions and malformed action SHAs' {
        $badShell = 'steps:
  - run: echo test
    shell: ${{ matrix.shell }}'
        $badSha = 'steps:
  - uses: actions/checkout@12345'
        $goodWf = 'steps:
  - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
    shell: pwsh'

        ($badShell -match '(?m)^\s*shell:\s*\$\{\{') | Should -Be $true
        ($goodWf -match '(?m)^\s*shell:\s*\$\{\{') | Should -Be $false

        $badShaMatch = [regex]::Match($badSha, 'uses:\s*[\w\.\-]+/[\w\.\-]+@([a-fA-F0-9]+)')
        $badShaMatch.Success | Should -Be $true
        ($badShaMatch.Groups[1].Value.Length -ne 40) | Should -Be $true

        $goodShaMatch = [regex]::Match($goodWf, 'uses:\s*[\w\.\-]+/[\w\.\-]+@([a-fA-F0-9]+)')
        $goodShaMatch.Success | Should -Be $true
        ($goodShaMatch.Groups[1].Value.Length -eq 40) | Should -Be $true
    }

    It 'DryRun failure scanner detects FAILED, FAIL, and ERROR tokens correctly' {
        $pattern = '\b(FAIL|FAILED|ERROR):'
        "  FAILED: Could not remove file" | Should -Match $pattern
        "  FAIL: Access denied" | Should -Match $pattern
        "  ERROR: Service failed to start" | Should -Match $pattern

        # Must NOT match clean operation lines
        "  REMOVED: Sponsored shortcut" | Should -Not -Match $pattern
        "  RESTORED: SysMain = Automatic" | Should -Not -Match $pattern
        "  SKIP: Firewall rule not found" | Should -Not -Match $pattern
        "  KEEP: Microsoft Store automatic updates retained" | Should -Not -Match $pattern
    }
}

Describe 'Test-MasterGate: Execution & Exit Code Contracts' -Tag 'Unit', 'MasterGate' {
    It 'Enforces mutual exclusivity between -Win11 and -Win10' {
        $proc = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$script:gateScript`"", "-Win11", "-Win10" -NoNewWindow -PassThru -Wait -RedirectStandardError "nul"
        $proc.ExitCode | Should -Be 1
    }

    It 'Enforces mutual exclusivity when -Both is combined with -Win11 or -Win10' {
        $proc1 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$script:gateScript`"", "-Both", "-Win11" -NoNewWindow -PassThru -Wait -RedirectStandardError "nul"
        $proc1.ExitCode | Should -Be 1

        $proc2 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$script:gateScript`"", "-Both", "-Win10" -NoNewWindow -PassThru -Wait -RedirectStandardError "nul"
        $proc2.ExitCode | Should -Be 1
    }

    It 'Executes -Fast gate successfully with exit code 0' {
        $proc = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$script:gateScript`"", "-Fast" -NoNewWindow -PassThru -Wait -RedirectStandardError "nul"
        $proc.ExitCode | Should -Be 0
    }
}
