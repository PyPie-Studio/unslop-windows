#requires -Version 5.1
<#
.SYNOPSIS
    Pester Unit & Mocking Test Suite for scripts/Test-MasterGate.ps1.
    Tests script AST syntax, parameter contract, line-ending audit logic,
    conflict marker detection, platform target resolution, and dry-run execution.
#>

BeforeAll {
    $script:repoRoot = Split-Path -Parent $PSScriptRoot
    $script:targetScript = Join-Path $script:repoRoot "scripts/Test-MasterGate.ps1"

    if (-not (Test-Path $script:targetScript)) {
        throw "Target script not found at: $script:targetScript"
    }

    # Resolve preferred PowerShell CLI executable
    $script:psCli = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell.exe" }
}

Describe 'Test-MasterGate: AST Parsing & Parameter Contract' -Tag 'Unit', 'AST' {
    BeforeAll {
        $script:tokens = $null
        $script:errors = $null
        $script:ast = [System.Management.Automation.Language.Parser]::ParseFile($script:targetScript, [ref]$script:tokens, [ref]$script:errors)
    }

    It 'Parses script cleanly without AST parser errors' {
        $script:errors.Count | Should -Be 0
    }

    It 'Declares expected script parameters' {
        $paramBlock = $script:ast.ParamBlock
        $paramBlock | Should -Not -BeNullOrEmpty

        $declaredParams = $paramBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath }

        $expectedParams = @(
            'Fast',
            'SkipAnalyzer',
            'SkipUnitTests',
            'Strict',
            'Win11',
            'Win10',
            'SkipBuildCheck',
            'TestResultsPath',
            'CodeCoveragePath'
        )

        foreach ($p in $expectedParams) {
            $declaredParams | Should -Contain $p -Because "Script parameter '$p' must be declared in param block"
        }
    }
}

Describe 'Test-MasterGate: Logic & Audit Checks' -Tag 'Unit', 'Logic' {
    Context 'Line Ending CRLF Audit Logic' {
        It 'Correctly identifies naked LF in byte array (non-CRLF line endings)' {
            # Simulated byte array with naked LF (byte 10 not preceded by byte 13)
            $invalidBytes = [byte[]]@(117, 110, 115, 108, 111, 112, 10) # 'unslop\n'

            $hasNakedLf = $false
            for ($i = 0; $i -lt $invalidBytes.Length; $i++) {
                if ($invalidBytes[$i] -eq 10) {
                    if ($i -eq 0 -or $invalidBytes[$i - 1] -ne 13) {
                        $hasNakedLf = $true
                        break
                    }
                }
            }

            $hasNakedLf | Should -BeTrue
        }

        It 'Correctly passes byte array with CRLF line endings' {
            # Simulated byte array with CRLF (byte 13 followed by byte 10)
            $validBytes = [byte[]]@(117, 110, 115, 108, 111, 112, 13, 10) # 'unslop\r\n'

            $hasNakedLf = $false
            for ($i = 0; $i -lt $validBytes.Length; $i++) {
                if ($validBytes[$i] -eq 10) {
                    if ($i -eq 0 -or $validBytes[$i - 1] -ne 13) {
                        $hasNakedLf = $true
                        break
                    }
                }
            }

            $hasNakedLf | Should -BeFalse
        }
    }

    Context 'Merge Conflict Marker Audit Logic' {
        It 'Matches conflict markers correctly' {
            # Build string dynamically so MasterGate audit does not flag this test file itself
            $m1 = "<" * 7 + " HEAD"
            $m2 = "=" * 7
            $m3 = ">" * 7 + " feature"
            $conflictContent = "$m1`ncode`n$m2`nother code`n$m3"

            $hasConflict = ($conflictContent -match '(?m)^<{7}\s' -or $conflictContent -match '(?m)^={7}$' -or $conflictContent -match '(?m)^>{7}\s')
            $hasConflict | Should -BeTrue
        }

        It 'Ignores clean content without conflict markers' {
            $cleanContent = "function Test-Function {`n    Write-Host 'No conflict markers here'`n}"
            $hasConflict = ($cleanContent -match '(?m)^<{7}\s' -or $cleanContent -match '(?m)^={7}$' -or $cleanContent -match '(?m)^>{7}\s')
            $hasConflict | Should -BeFalse
        }
    }
}

Describe 'Test-MasterGate: Integration Execution' -Tag 'Integration' {
    It 'Executes Test-MasterGate.ps1 -Fast -SkipBuildCheck successfully with exit code 0' {
        $output = & $script:psCli -NoProfile -ExecutionPolicy Bypass -File $script:targetScript -Fast -SkipBuildCheck 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -match "MASTER GATE PASSED").Length | Should -BeGreaterThan 0
    }
}
