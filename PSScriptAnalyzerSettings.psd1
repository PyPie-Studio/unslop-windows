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

    # Exclude rules that do not apply to monolithic debloater scripts
    ExcludeRules = @(
        # Internal helper functions in unslop.ps1 do not require separate comment-based help blocks
        'PSProvideCommentHelp',
        # Intentional positional parameter usage in internal helper function calls
        'PSAvoidUsingPositionalParameters',
        # Script deliberately manages script-level state ($script:log)
        'PSAvoidGlobalVars'
    )
}
