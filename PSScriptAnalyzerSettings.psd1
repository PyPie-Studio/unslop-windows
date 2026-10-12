@{
    # Severity levels to include: Error and Warning
    Severity = @('Error', 'Warning')

    # Include all default built-in PSScriptAnalyzer rules
    IncludeDefaultRules = $true

    # Custom rule configurations
    Rules = @{
        PSAvoidUsingCmdletAliases = @{
            Enable = $true
        }
        PSAvoidUsingEmptyCatchBlock = @{
            Enable = $true
        }
        PSAvoidUsingPlainTextForPassword = @{
            Enable = $true
        }
        PSAvoidUsingInvokeExpression = @{
            Enable = $true
        }
        PSAvoidUsingUsernameAndPasswordParams = @{
            Enable = $true
        }
    }

    # Exclude rules that do not apply to monolithic debloater scripts and test suites
    ExcludeRules = @(
        # Internal helper functions in unslop-win11.ps1 and unslop-win10.ps1 do not require separate comment-based help blocks
        'PSProvideCommentHelp',
        # Intentional positional parameter usage in internal helper function calls
        'PSAvoidUsingPositionalParameters',
        # Script deliberately manages script-level state ($script:log)
        'PSAvoidGlobalVars',
        # Standalone interactive CLI debloaters use Write-Host for colored terminal UI, banners, and restart countdowns
        'PSAvoidUsingWriteHost',
        # Internal helper functions utilize custom -DryRun gating rather than PowerShell ShouldProcess/WhatIf
        'PSUseShouldProcessForStateChangingFunctions',
        # Unit test suites declare cross-platform test stubs to enable mocking of Windows cmdlets
        'PSAvoidOverwritingBuiltInCmdlets',
        # Unit test mocks and parameter filter scriptblocks declare cmdlet parameters without consuming them
        'PSReviewUnusedParameter',
        # Internal helper and diagnostic functions (e.g. Get-SystemMetrics) intentionally use domain plural nouns
        'PSUseSingularNouns'
    )
}
