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

#endregion

#region Commit Helper Functions

<#
.SYNOPSIS
    Analyzes diff statistics from git diff output
    
.DESCRIPTION
    Parses git diff output to extract statistics about changes including
    lines added, deleted, and files modified.
    
.PARAMETER DiffOutput
    Array of git diff output lines
    
.EXAMPLE
    $diff = git diff --stat HEAD
    $stats = Get-DiffStatistics -DiffOutput $diff
#>
function Get-DiffStatistics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$DiffOutput
    )
    
    $stats = @{
        LinesAdded = 0
        LinesDeleted = 0
        FilesChanged = 0
        FilesAnalyzed = @()
    }
    
    foreach ($line in $DiffOutput) {
        # Parse summary line: "X files changed, Y insertions(+), Z deletions(-)"
        if ($line -match '(\d+) files? changed') {
            $stats.FilesChanged = [int]$matches[1]
        }
        if ($line -match '(\d+) insertion') {
            $stats.LinesAdded = [int]$matches[1]
        }
        if ($line -match '(\d+) deletion') {
            $stats.LinesDeleted = [int]$matches[1]
        }
        
        # Parse individual file stats
        if ($line -match '^([^\|]+)\s*\|\s*(\d+)\s*([+-]+)?$') {
            $stats.FilesAnalyzed += @{
                Name = $matches[1].Trim()
                Changes = [int]$matches[2]
                Visual = if ($matches[3]) { $matches[3] } else { "" }
            }
        }
    }
    
    return $stats
}

<#
.SYNOPSIS
    Selects appropriate message template based on analysis
    
.DESCRIPTION
    Determines the best commit message template to use based on
    staged changes analysis and user preferences.
    
.PARAMETER Analysis
    Hashtable containing analysis of staged changes
    
.PARAMETER RequestedTemplate
    Optional specific template name requested by user
    
.PARAMETER Config
    Configuration object containing available templates
    
.EXAMPLE
    $template = Select-MessageTemplate -Analysis $analysis -Config $config
#>
function Select-MessageTemplate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Analysis,
        
        [string]$RequestedTemplate,
        
        [Parameter(Mandatory)]
        [hashtable]$Config
    )
    
    # If specific template requested, use it
    if ($RequestedTemplate -and $Config.MessageGeneration.Templates.ContainsKey($RequestedTemplate)) {
        return $Config.MessageGeneration.Templates[$RequestedTemplate]
    }
    
    # Auto-detect type from analysis
    $detectedType = "default"
    
    if ($Analysis.Type) {
        $detectedType = $Analysis.Type
    }
    
    # Select based on detected type
    if ($Config.MessageGeneration.Templates.ContainsKey($detectedType)) {
        return $Config.MessageGeneration.Templates[$detectedType]
    }
    
    # Fallback to default template
    return $Config.MessageGeneration.Templates["default"]
}

<#
.SYNOPSIS
    Builds commit message from analysis and template
    
.DESCRIPTION
    Constructs a commit message by filling in template placeholders
    with information from the staged changes analysis.
    
.PARAMETER Analysis
    Hashtable containing analysis data (type, scope, keywords, etc.)
    
.PARAMETER Template
    Template object with Format and Description
    
.PARAMETER Config
    Configuration object
    
.EXAMPLE
    $message = Build-CommitMessage -Analysis $analysis -Template $template -Config $config
#>
function Build-CommitMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Analysis,
        
        [Parameter(Mandatory)]
        $Template
    )
    
    $message = $Template.Format
    
    # Replace placeholders with actual values
    if ($Analysis.Type) {
        $message = $message -replace '\{type\}', $Analysis.Type
    }
    
    if ($Analysis.Scope -and $Analysis.Scope.Count -gt 0) {
        $scopeStr = $Analysis.Scope -join ', '
        $message = $message -replace '\{scope\}', $scopeStr
    }
    else {
        # Remove scope placeholder if no scope detected
        $message = $message -replace '\(?\{scope\}\)?:?\s*', ''
    }
    
    if ($Analysis.Keywords -and $Analysis.Keywords.Count -gt 0) {
        $keywordsStr = $Analysis.Keywords -join ' '
        $message = $message -replace '\{keywords\}', $keywordsStr
    }
    else {
        $message = $message -replace '\{keywords\}', 'files'
    }
    
    # Clean up any remaining placeholders
    $message = $message -replace '\{[^}]+\}', ''
    
    return $message.Trim()
}

<#
.SYNOPSIS
    Analyzes file types in staged changes
    
.DESCRIPTION
    Examines staged files to determine predominant file types,
    directory scopes, and change patterns.
    
.PARAMETER Files
    Array of file information objects from staged changes
    
.EXAMPLE
    $analysis = Get-FileTypeAnalysis -Files $stagedChanges.Files
#>
function Get-FileTypeAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Files
    )
    
    $analysis = @{
        Types = @()
        Scopes = @()
        Keywords = @()
        PrimaryType = $null
    }
    
    if ($Files.Count -eq 0) {
        return $analysis
    }
    
    # Analyze file extensions
    $fileGroups = $Files | Group-Object { 
        $ext = [System.IO.Path]::GetExtension($_.Name)
        if ($ext) { $ext.TrimStart('.') } else { 'no-extension' }
    }
    
    $analysis.Types = $fileGroups | ForEach-Object { $_.Name }
    $analysis.PrimaryType = ($fileGroups | Sort-Object Count -Descending | Select-Object -First 1).Name
    
    # Determine scopes from paths (directories)
    $pathParts = $Files | ForEach-Object { 
        $parts = $_.Name -split '[/\\]'
        if ($parts.Count -gt 1) { $parts[0] } 
    } | Where-Object { $_ } | Group-Object | Sort-Object Count -Descending | Select-Object -First 3
    
    if ($pathParts) {
        $analysis.Scopes = $pathParts | ForEach-Object { $_.Name }
    }
    
    # Generate keywords from file names
    $keywords = $Files | ForEach-Object {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
        $name -split '[_\-\.]'
    } | Where-Object { $_ -and $_.Length -gt 2 } | Group-Object | Sort-Object Count -Descending | Select-Object -First 5
    
    if ($keywords) {
        $analysis.Keywords = $keywords | ForEach-Object { $_.Name }
    }
    
    return $analysis
}

<#
.SYNOPSIS
    Formats message according to conventional commits specification
    
.DESCRIPTION
    Converts a regular commit message to conventional commits format,
    automatically detecting the type and scope where possible.
    
.PARAMETER Message
    The commit message to format
    
.PARAMETER StagedChanges
    Hashtable containing staged changes information
    
.EXAMPLE
    $formatted = Format-ConventionalCommit -Message "updated user auth" -StagedChanges $changes
#>
function Format-ConventionalCommit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter(Mandatory)]
        [hashtable]$StagedChanges
    )
    
    # Check if already in conventional format
    if ($Message -match '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?!?:\s') {
        return $Message
    }
    
    # Try to determine type from message content
    $type = "chore"
    $messageLower = $Message.ToLower()
    
    if ($messageLower -match '\b(add|new|implement|create|feature)\b') { 
        $type = "feat" 
    }
    elseif ($messageLower -match '\b(fix|bug|error|issue|resolve|patch)\b') { 
        $type = "fix" 
    }
    elseif ($messageLower -match '\b(doc|readme|comment|documentation)\b') { 
        $type = "docs" 
    }
    elseif ($messageLower -match '\b(refactor|restructure|reorganize)\b') { 
        $type = "refactor" 
    }
    elseif ($messageLower -match '\b(test|spec|unit|integration)\b') { 
        $type = "test" 
    }
    elseif ($messageLower -match '\b(style|format|lint|prettier)\b') { 
        $type = "style" 
    }
    elseif ($messageLower -match '\b(perf|performance|optimize|speed)\b') { 
        $type = "perf" 
    }
    elseif ($messageLower -match '\b(build|compile|package|deploy)\b') { 
        $type = "build" 
    }
    
    # Get scope from staged changes
    $scope = Get-CommitScope -StagedChanges $StagedChanges
    
    # Ensure message starts with lowercase (conventional commits style)
    $Message = $Message.Substring(0, 1).ToLower() + $Message.Substring(1)
    
    # Build formatted message
    if ($scope) {
        return "$type($scope)`: $Message"
    }
    else {
        return "$type`: $Message"
    }
}

<#
.SYNOPSIS
    Determines commit scope from staged changes
    
.DESCRIPTION
    Analyzes staged files to determine the most appropriate scope
    for a conventional commit message.
    
.PARAMETER StagedChanges
    Hashtable containing staged changes information
    
.EXAMPLE
    $scope = Get-CommitScope -StagedChanges $changes
#>
function Get-CommitScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$StagedChanges
    )
    
    if (-not $StagedChanges.Files -or $StagedChanges.Files.Count -eq 0) {
        return $null
    }
    
    # Get most common directory/component
    $dirs = $StagedChanges.Files | ForEach-Object {
        $parts = $_.Name -split '[/\\]'
        if ($parts.Count -gt 1) { 
            $parts[0] 
        }
        else { 
            $null
        }
    } | Where-Object { $_ } | Group-Object | Sort-Object Count -Descending | Select-Object -First 1
    
    # Only use as scope if it represents majority of changes
    if ($dirs -and $dirs.Count -gt ($StagedChanges.Files.Count * 0.5)) {
        return $dirs.Name
    }
    
    # Check for common patterns
    $allFiles = $StagedChanges.Files.Name -join ' '
    
    if ($allFiles -match '\btest') { return 'tests' }
    if ($allFiles -match '\bdoc') { return 'docs' }
    if ($allFiles -match '\bconfig') { return 'config' }
    if ($allFiles -match '\blib|src') { return 'core' }
    
    return $null
}

<#
.SYNOPSIS
    Validates commit message quality
    
.DESCRIPTION
    Checks a commit message against best practices and common guidelines,
    returning validation results with warnings and suggestions.
    
.PARAMETER Message
    The commit message to validate
    
.EXAMPLE
    $validation = Test-CommitMessage -Message "fix: resolve auth bug"
#>
function Test-CommitMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )
    
    $validation = @{
        IsValid = $true
        Warnings = @()
        Errors = @()
        Suggestions = @()
    }
    
    # Check minimum length
    if ($Message.Length -lt 10) {
        $validation.Warnings += "Commit message is very short (less than 10 characters)"
    }
    
    # Check maximum length for first line
    $firstLine = ($Message -split "`n")[0]
    if ($firstLine.Length -gt 72) {
        $validation.Warnings += "First line is longer than 72 characters (${firstLine.Length} chars)"
    }
    
    # Check for common placeholders
    if ($Message -match '^\s*(wip|tmp|temp|test|TODO|FIXME)\s*$') {
        $validation.Warnings += "Message appears to be a placeholder. Consider using a more descriptive message."
    }
    
    # Check for imperative mood (basic heuristic)
    if ($Message -match '^\s*(updated|fixed|added|changed|removed|deleted)') {
        $validation.Suggestions += "Consider using imperative mood: 'update' instead of 'updated', 'fix' instead of 'fixed'"
    }
    
    # Check for trailing period
    if ($firstLine -match '\.\s*$') {
        $validation.Suggestions += "Commit message subject should not end with a period"
    }
    
    # Check for all caps
    if ($Message -cmatch '^[A-Z\s]+$' -and $Message.Length -gt 5) {
        $validation.Warnings += "Avoid using all caps in commit messages"
    }
    
    # Positive patterns
    if ($Message -match '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore)\(') {
        $validation.Suggestions += "Great! Using conventional commits format"
    }
    
    return $validation
}

<#
.SYNOPSIS
    Performs pre-commit validation checks
    
.DESCRIPTION
    Runs various checks on staged changes before allowing a commit,
    including detecting debug statements, large files, and other issues.
    
.PARAMETER StagedChanges
    Hashtable containing information about staged changes
    
.EXAMPLE
    $preCommit = Invoke-PreCommitValidation -StagedChanges $changes
#>
function Invoke-PreCommitValidation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$StagedChanges
    )
    
    $results = @{
        BlockingIssues = @()
        Warnings = @()
        Info = @()
    }
    
    if (-not $StagedChanges.Files -or $StagedChanges.Files.Count -eq 0) {
        return $results
    }
    
    foreach ($file in $StagedChanges.Files) {
        $fileName = $file.Name
        
        # Check PowerShell files for debug statements
        if ($fileName -match '\.(ps1|psm1|psd1)$') {
            try {
                $content = git show ":$fileName" 2>$null
                
                if ($content -match 'Write-Debug|Set-PSBreakpoint|\$DebugPreference\s*=\s*[''"]Continue') {
                    $results.Warnings += "Debug statements found in $fileName"
                }
                
                # Check for console.log (in case of mixed JS/PS projects)
                if ($content -match 'console\.log|debugger;') {
                    $results.Warnings += "JavaScript debug statements found in $fileName"
                }
            }
            catch {
                Write-Verbose "Could not read file for validation: $fileName - $_"
            }
        }
        
        # Check for large files
        if (Test-Path $fileName) {
            $fileInfo = Get-Item $fileName -ErrorAction SilentlyContinue
            if ($fileInfo) {
                $size = $fileInfo.Length
                
                if ($size -gt 10MB) {
                    $sizeMB = [math]::Round($size / 1MB, 2)
                    $results.BlockingIssues += "Very large file detected: $fileName ($sizeMB MB). Consider Git LFS."
                }
                elseif ($size -gt 1MB) {
                    $sizeMB = [math]::Round($size / 1MB, 2)
                    $results.Warnings += "Large file detected: $fileName ($sizeMB MB)"
                }
            }
        }
        
        # Check for sensitive patterns
        try {
            $content = git show ":$fileName" 2>$null
            
            if ($content -match 'password\s*=|api[_-]?key\s*=|secret\s*=|token\s*=') {
                $results.Warnings += "Possible sensitive data in $fileName. Review carefully."
            }
        }
        catch {
            Write-Verbose "Could not check for sensitive data in: $fileName - $_"
        }
    }
    
    return $results
}

#endregion

# Export all functions including commit helpers
Export-ModuleMember -Function @(
    'Invoke-SafeScriptBlock',
    'Format-FileSize',
    'Format-Duration',
    'Test-GitRepository',
    'Get-GitRepositoryRoot',
    'ConvertTo-SafeFileName',
    'New-GitZoomTempDirectory',
    'Clear-GitZoomTempDirectories',
    'ConvertTo-JsonFormatted',
    'Get-UserGitConfig',
    'Get-DiffStatistics',
    'Select-MessageTemplate',
    'Build-CommitMessage',
    'Get-FileTypeAnalysis',
    'Format-ConventionalCommit',
    'Get-CommitScope',
    'Test-CommitMessage',
    'Invoke-PreCommitValidation'
)