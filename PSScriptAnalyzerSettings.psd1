@{
    # Severity levels to include
    Severity = @('Error', 'Warning')

    # Rules to exclude
    ExcludeRules = @(
        # Write-Host is used intentionally for user-facing formatted output
        'PSAvoidUsingWriteHost',
        
        # Global variables are used intentionally in ErrorHandling module for context tracking
        'PSAvoidGlobalVars',
        
        # BOM encoding warnings - UTF-8 without BOM is standard for cross-platform compatibility
        'PSUseBOMForUnicodeEncodedFile',
        
        # Plural nouns are sometimes more readable for collections
        # Will review these case-by-case but not blocking
        'PSUseSingularNouns'
    )

    # Rules to include
    IncludeRules = @(
        'PSAvoidUsingEmptyCatchBlock',
        'PSReviewUnusedParameter',
        'PSUseShouldProcessForStateChangingFunctions'
    )
}
