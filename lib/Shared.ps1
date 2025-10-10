<#
.SYNOPSIS
    Shared utility functions for GitZoom to reduce code duplication.
.DESCRIPTION
    Contains common patterns used across multiple modules, such as error handling
    for git commands and repository validation.
#>

#region Shared Functions

<#
.SYNOPSIS
    Validates git installation and repository presence.
.DESCRIPTION
    Common validation logic used by multiple functions.
#>
function Test-GitEnvironment {
    [CmdletBinding()]
    param()

    # Check if git is installed
    try {
        $null = Get-Command git -ErrorAction Stop
    } catch {
        throw "Git is not installed or not in PATH."
    }

    # Check if we're in a git repository
    if (-not (Test-GitRepository)) {
        throw "Not in a git repository."
    }
}

<#
.SYNOPSIS
    Executes a git command with standardized error handling.
.DESCRIPTION
    Wraps git command execution with consistent error handling and logging.
.PARAMETER Arguments
    Array of arguments to pass to git.
.PARAMETER ErrorMessage
    Custom error message if the command fails.
#>
function Invoke-GitCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [string]$ErrorMessage = "Git command failed"
    )

    try {
        $result = & git $Arguments 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "$ErrorMessage`: $($result -join "`n")"
        }
        return $result
    } catch {
        Write-Error $_.Exception.Message
        throw
    }
}

<#
.SYNOPSIS
    Gets cached git status to avoid repeated calls.
.DESCRIPTION
    Caches git status results for a short time to reduce redundant calls.
#>
function Get-CachedGitStatus {
    [CmdletBinding()]
    param()

    $cacheKey = "GitStatus_$(Get-Location)"
    $cacheTime = 5  # seconds

    if ($script:StatusCache -and
        $script:StatusCache.Key -eq $cacheKey -and
        ((Get-Date) - $script:StatusCache.Time).TotalSeconds -lt $cacheTime) {
        return $script:StatusCache.Status
    }

    $status = Invoke-GitCommand -Arguments @('status', '--porcelain') -ErrorMessage "Failed to get git status"
    $script:StatusCache = @{
        Key = $cacheKey
        Status = $status
        Time = Get-Date
    }

    return $status
}

# Initialize cache
$script:StatusCache = $null

Export-ModuleMember -Function Test-GitEnvironment, Invoke-GitCommand, Get-CachedGitStatus
