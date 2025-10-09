<#
.SYNOPSIS
    GitZoom Utility Functions
    
.DESCRIPTION
    Common utility functions used across GitZoom modules for
    file operations, string manipulation, and helper functions.
#>

#region Utility Functions

<#
.SYNOPSIS
    Safely executes a script block with error handling
    
.DESCRIPTION
    Provides a wrapper for executing code blocks with consistent error handling
    and optional retry logic.
    
.PARAMETER ScriptBlock
    The script block to execute
    
.PARAMETER ErrorMessage
    Custom error message if execution fails
    
.PARAMETER RetryCount
    Number of retry attempts (default: 0)
    
.EXAMPLE
    Invoke-SafeScriptBlock { Get-ChildItem } -ErrorMessage "Failed to list directory"
#>
function Invoke-SafeScriptBlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ScriptBlock]$ScriptBlock,
        
        [string]$ErrorMessage = "Script block execution failed",
        
        [int]$RetryCount = 0
    )
    
    $attempt = 0
    $maxAttempts = $RetryCount + 1
    
    while ($attempt -lt $maxAttempts) {
        $attempt++
        
        try {
            return & $ScriptBlock
        }
        catch {
            if ($attempt -ge $maxAttempts) {
                if ($ErrorMessage) {
                    throw "$ErrorMessage`: $($_.Exception.Message)"
                }
                else {
                    throw
                }
            }
            
            # Wait before retry
            Start-Sleep -Milliseconds (100 * $attempt)
        }
    }
}

<#
.SYNOPSIS
    Formats a file size in human-readable format
    
.PARAMETER Bytes
    Size in bytes
    
.EXAMPLE
    Format-FileSize -Bytes 1048576
    # Returns "1.00 MB"
#>
function Format-FileSize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [long]$Bytes
    )
    
    $sizes = @("B", "KB", "MB", "GB", "TB")
    $index = 0
    $size = [double]$Bytes
    
    while ($size -ge 1024 -and $index -lt ($sizes.Length - 1)) {
        $size = $size / 1024
        $index++
    }
    
    return "{0:N2} {1}" -f $size, $sizes[$index]
}

<#
.SYNOPSIS
    Converts a timespan to human-readable format
    
.PARAMETER TimeSpan
    TimeSpan object to format
    
.EXAMPLE
    Format-Duration -TimeSpan (New-TimeSpan -Seconds 75)
    # Returns "1m 15s"
#>
function Format-Duration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [TimeSpan]$TimeSpan
    )
    
    $parts = @()
    
    if ($TimeSpan.Days -gt 0) {
        $parts += "$($TimeSpan.Days)d"
    }
    if ($TimeSpan.Hours -gt 0) {
        $parts += "$($TimeSpan.Hours)h"
    }
    if ($TimeSpan.Minutes -gt 0) {
        $parts += "$($TimeSpan.Minutes)m"
    }
    if ($TimeSpan.Seconds -gt 0 -or $parts.Count -eq 0) {
        $parts += "$($TimeSpan.Seconds)s"
    }
    
    return $parts -join " "
}

<#
.SYNOPSIS
    Validates that a path is within a Git repository
    
.PARAMETER Path
    Path to validate
    
.EXAMPLE
    Test-GitRepository -Path "C:\Projects\MyRepo"
#>
function Test-GitRepository {
    [CmdletBinding()]
    param(
        [string]$Path = (Get-Location).Path
    )
    
    try {
        Push-Location $Path
        $gitRoot = git rev-parse --show-toplevel 2>$null
        return ($LASTEXITCODE -eq 0 -and $gitRoot)
    }
    catch {
        return $false
    }
    finally {
        Pop-Location
    }
}

<#
.SYNOPSIS
    Gets the Git repository root path
    
.PARAMETER Path
    Path within the repository
    
.EXAMPLE
    Get-GitRepositoryRoot
#>
function Get-GitRepositoryRoot {
    [CmdletBinding()]
    param(
        [string]$Path = (Get-Location).Path
    )
    
    try {
        Push-Location $Path
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and $gitRoot) {
            return $gitRoot -replace '/', '\'  # Convert to Windows paths
        }
        return $null
    }
    catch {
        return $null
    }
    finally {
        Pop-Location
    }
}

<#
.SYNOPSIS
    Sanitizes a string for use in file names
    
.PARAMETER InputString
    String to sanitize
    
.EXAMPLE
    ConvertTo-SafeFileName -InputString "My File: Name?"
    # Returns "My File- Name-"
#>
function ConvertTo-SafeFileName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InputString
    )
    
    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    $safeString = $InputString
    
    foreach ($char in $invalidChars) {
        $safeString = $safeString -replace [regex]::Escape($char), '-'
    }
    
    # Remove multiple consecutive dashes
    $safeString = $safeString -replace '-+', '-'
    
    # Trim dashes from start and end
    return $safeString.Trim('-')
}

<#
.SYNOPSIS
    Creates a temporary directory for GitZoom operations
    
.EXAMPLE
    New-GitZoomTempDirectory
#>
function New-GitZoomTempDirectory {
    [CmdletBinding()]
    param()
    
    $tempBase = Join-Path $env:TEMP "GitZoom"
    $tempDir = Join-Path $tempBase "temp-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$(Get-Random -Minimum 1000 -Maximum 9999)"
    
    if (-not (Test-Path $tempDir)) {
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
    }
    
    return $tempDir
}

<#
.SYNOPSIS
    Cleans up temporary GitZoom directories older than specified age
    
.PARAMETER MaxAge
    Maximum age of temporary directories to keep (default: 1 day)
    
.EXAMPLE
    Clear-GitZoomTempDirectories -MaxAge (New-TimeSpan -Hours 6)
#>
function Clear-GitZoomTempDirectories {
    [CmdletBinding()]
    param(
        [TimeSpan]$MaxAge = (New-TimeSpan -Days 1)
    )
    
    $tempBase = Join-Path $env:TEMP "GitZoom"
    if (-not (Test-Path $tempBase)) {
        return
    }
    
    $cutoffTime = (Get-Date) - $MaxAge
    
    try {
        Get-ChildItem -Path $tempBase -Directory | Where-Object {
            $_.Name -match '^temp-\d{8}-\d{6}-\d{4}$' -and $_.CreationTime -lt $cutoffTime
        } | ForEach-Object {
            try {
                Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                Write-Verbose "Cleaned up temporary directory: $($_.Name)"
            }
            catch {
                Write-Verbose "Failed to clean up temporary directory: $($_.Name)"
            }
        }
    }
    catch {
        Write-Verbose "Failed to clean up temporary directories: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Converts hashtable to JSON with proper formatting
    
.PARAMETER InputObject
    Hashtable to convert
    
.PARAMETER Depth
    Maximum depth for nested objects
    
.EXAMPLE
    ConvertTo-JsonFormatted -InputObject @{key="value"} -Depth 5
#>
function ConvertTo-JsonFormatted {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$InputObject,
        
        [int]$Depth = 10
    )
    
    try {
        return $InputObject | ConvertTo-Json -Depth $Depth
    }
    catch {
        # Fallback for older PowerShell versions
        return $InputObject | ConvertTo-Json
    }
}

<#
.SYNOPSIS
    Gets the current user's Git configuration
    
.EXAMPLE
    Get-UserGitConfig
#>
function Get-UserGitConfig {
    [CmdletBinding()]
    param()
    
    $config = @{}
    
    try {
        $userName = git config user.name 2>$null
        if ($LASTEXITCODE -eq 0 -and $userName) {
            $config.UserName = $userName
        }
        
        $userEmail = git config user.email 2>$null
        if ($LASTEXITCODE -eq 0 -and $userEmail) {
            $config.UserEmail = $userEmail
        }
        
        return $config
    }
    catch {
        return @{}
    }
}

#endregion

# Export functions
Export-ModuleMember -Function @(
    "Invoke-SafeScriptBlock",
    "Format-FileSize",
    "Format-Duration",
    "Test-GitRepository",
    "Get-GitRepositoryRoot",
    "ConvertTo-SafeFileName",
    "New-GitZoomTempDirectory",
    "Clear-GitZoomTempDirectories",
    "ConvertTo-JsonFormatted",
    "Get-UserGitConfig"
)