<#
.SYNOPSIS
    GitZoom Smart Commit Engine
    
.DESCRIPTION
    Provides intelligent commit operations with automated message optimization,
    performance tracking, and advanced Git workflow management.
#>

#region Commit Operations

<#
.SYNOPSIS
    Performs intelligent commit operation with optimized messages
    
.DESCRIPTION
    Advanced commit function that analyzes staged changes, generates or optimizes
    commit messages, and tracks performance for continuous improvement.
    
.PARAMETER Message
    Commit message (will be optimized if provided)
    
.PARAMETER AutoGenerate
    Automatically generate commit message from staged changes
    
.PARAMETER Template
    Use predefined commit message template
    
.PARAMETER AllowEmpty
    Allow commit with no staged changes
    
.PARAMETER Amend
    Amend the previous commit
    
.PARAMETER Interactive
    Use interactive commit mode
    
.EXAMPLE
    Invoke-SmartCommit -Message "Fix user authentication bug"
    
.EXAMPLE
    Invoke-SmartCommit -AutoGenerate -Template "feature"
#>
function Invoke-SmartCommit {
    [CmdletBinding()]
    param(
        [string]$Message,
        [switch]$AutoGenerate,
        [string]$Template,
        [switch]$AllowEmpty,
        [switch]$Amend,
        [switch]$Interactive
    )
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $results = @{
        CommitHash = $null
        Message = $null
        StagedFiles = @()
        Performance = @{}
        Errors = @()
        Warnings = @()
    }
    
    try {
        Write-Verbose "Starting smart commit operation..."
        
        # Get staged changes
        $stagedChanges = Get-StagedChanges
        $results.StagedFiles = $stagedChanges.Files
        
        # Validate commit conditions
        $validation = Test-CommitConditions -StagedChanges $stagedChanges -AllowEmpty:$AllowEmpty
        if (-not $validation.IsValid) {
            foreach ($validationError in $validation.Errors) {
                $results.Errors += $validationError
            }
            return $results
        }
        
        # Handle message generation/optimization
        if ($AutoGenerate -or -not $Message) {
            $generatedMessage = Get-CommitMessage -StagedChanges $stagedChanges -Template $Template
            if ($generatedMessage) {
                $Message = $generatedMessage
            }
            elseif (-not $Message) {
                $results.Errors += "No commit message provided and auto-generation failed"
                return $results
            }
        }
        
        # Optimize the commit message
        $optimizedMessage = Optimize-CommitMessage -Message $Message -StagedChanges $stagedChanges
        $results.Message = $optimizedMessage
        
        # Validate message quality
        $messageValidation = Test-CommitMessage -Message $optimizedMessage
        foreach ($warning in $messageValidation.Warnings) {
            $results.Warnings += $warning
        }
        
        # Pre-commit hooks and validations
        $preCommitResults = Invoke-PreCommitValidation -StagedChanges $stagedChanges
        if ($preCommitResults.BlockingIssues.Count -gt 0) {
            foreach ($issue in $preCommitResults.BlockingIssues) {
                $results.Errors += "Pre-commit validation failed: $issue"
            }
            return $results
        }
        
        # Add warnings from pre-commit
        foreach ($warning in $preCommitResults.Warnings) {
            $results.Warnings += $warning
        }
        
        # Execute the commit
        $commitResult = Invoke-GitCommit -Message $optimizedMessage -Amend:$Amend -AllowEmpty:$AllowEmpty -Interactive:$Interactive
        
        if ($commitResult.Success) {
            $results.CommitHash = $commitResult.Hash
            Write-Verbose "Commit successful: $($commitResult.Hash)"
            
            # Post-commit operations
            Invoke-PostCommitOperations -CommitHash $commitResult.Hash -StagedFiles $results.StagedFiles
        }
        else {
            $results.Errors += $commitResult.Error
        }
        
        # Performance tracking
        $results.Performance.TotalTime = $stopwatch.ElapsedMilliseconds
        $results.Performance.FilesCommitted = $results.StagedFiles.Count
        $results.Performance.MessageLength = $optimizedMessage.Length
        
        # Record metrics for analysis
        Add-CommitMetric -Results $results
        
    }
    catch {
        $results.Errors += $_.Exception.Message
        Write-Error "Smart commit failed: $($_.Exception.Message)"
    }
    finally {
        $stopwatch.Stop()
    }
    
    return $results
}

<#
.SYNOPSIS
    Gets detailed information about staged changes
    
.DESCRIPTION
    Analyzes the current staging area to provide comprehensive information
    about files, change types, and content modifications.
    
.EXAMPLE
    Get-StagedChanges
#>
function Get-StagedChanges {
    [CmdletBinding()]
    param()
    
    $changes = @{
        Files = @()
        Stats = @{
            Added = 0
            Modified = 0
            Deleted = 0
            Renamed = 0
            Total = 0
        }
        Content = @{
            LinesAdded = 0
            LinesDeleted = 0
            FilesAnalyzed = @()
        }
    }
    
    try {
        # Get staged files with status
        $statusOutput = git diff --cached --name-status 2>$null
        
        if ($LASTEXITCODE -eq 0 -and $statusOutput) {
            foreach ($line in $statusOutput) {
                if ($line.Length -ge 3) {
                    $status = $line.Substring(0, 1)
                    $filename = $line.Substring(2).Trim()
                    
                    $fileInfo = @{
                        Name = $filename
                        Status = $status
                        FullPath = $filename
                    }
                    
                    # Categorize by status
                    switch ($status) {
                        'A' { 
                            $fileInfo.StatusDescription = "Added"
                            $changes.Stats.Added++
                        }
                        'M' { 
                            $fileInfo.StatusDescription = "Modified"
                            $changes.Stats.Modified++
                        }
                        'D' { 
                            $fileInfo.StatusDescription = "Deleted"
                            $changes.Stats.Deleted++
                        }
                        'R' { 
                            $fileInfo.StatusDescription = "Renamed"
                            $changes.Stats.Renamed++
                        }
                        default { 
                            $fileInfo.StatusDescription = "Unknown"
                        }
                    }
                    
                    $changes.Files += $fileInfo
                    $changes.Stats.Total++
                }
            }
        }
        
        # Get detailed diff statistics
        $diffStats = git diff --cached --stat 2>$null
        if ($LASTEXITCODE -eq 0 -and $diffStats) {
            $changes.Content = Get-DiffStatistics -DiffOutput $diffStats
        }
        
        Write-Verbose "Staged changes analysis complete:"
        Write-Verbose "  Files: $($changes.Stats.Total) (A:$($changes.Stats.Added) M:$($changes.Stats.Modified) D:$($changes.Stats.Deleted) R:$($changes.Stats.Renamed))"
        Write-Verbose "  Lines: +$($changes.Content.LinesAdded) -$($changes.Content.LinesDeleted)"
        
        return $changes
    }
    catch {
        Write-Error "Failed to analyze staged changes: $($_.Exception.Message)"
        return $changes
    }
}

<#
.SYNOPSIS
    Validates conditions for committing
    
.DESCRIPTION
    Checks various conditions that might prevent or warn about committing,
    such as no staged changes, large commits, or repository state issues.
    
.PARAMETER StagedChanges
    Staged changes object from Get-StagedChanges
    
.PARAMETER AllowEmpty
    Whether to allow commits with no changes
    
.EXAMPLE
    Test-CommitConditions -StagedChanges $changes
#>
function Test-CommitConditions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$StagedChanges,
        
        [switch]$AllowEmpty
    )
    
    $validation = @{
        IsValid = $true
        Errors = @()
        Warnings = @()
    }
    
    try {
        # Check for staged changes
        if ($StagedChanges.Stats.Total -eq 0 -and -not $AllowEmpty) {
            $validation.IsValid = $false
            $validation.Errors += "No changes staged for commit. Use 'git add' to stage changes or use -AllowEmpty flag."
        }
        
        # Check repository state
        $repoState = Get-RepositoryState
        
        # Check for merge conflicts
        if ($repoState.HasConflicts) {
            $validation.IsValid = $false
            $validation.Errors += "Repository has unresolved merge conflicts. Resolve conflicts before committing."
        }
        
        # Check for rebase in progress
        if ($repoState.RebaseInProgress) {
            # This might be okay, but warn user
            $validation.Warnings += "Rebase operation in progress. Ensure this commit is appropriate for the rebase."
        }
        
        # Check for large commits
        $config = Get-GitZoomConfig
        $maxFiles = $config.Commit.MaxFilesWarning
        $maxLines = $config.Commit.MaxLinesWarning
        
        if ($StagedChanges.Stats.Total -gt $maxFiles) {
            $validation.Warnings += "Large commit detected ($($StagedChanges.Stats.Total) files). Consider splitting into smaller commits."
        }
        
        $totalLines = $StagedChanges.Content.LinesAdded + $StagedChanges.Content.LinesDeleted
        if ($totalLines -gt $maxLines) {
            $validation.Warnings += "Large change set detected ($totalLines lines). Consider splitting into smaller commits."
        }
        
        # Check for uncommitted configuration files
        $configFiles = $StagedChanges.Files | Where-Object { 
            $_.Name -match '\.(env|config|conf|ini|json|yaml|yml)$' -or
            $_.Name -match '(package\.json|composer\.json|requirements\.txt|Gemfile)$'
        }
        
        if ($configFiles.Count -gt 0) {
            $validation.Warnings += "Configuration files detected in commit. Ensure sensitive data is not included."
        }
        
        return $validation
    }
    catch {
        $validation.IsValid = $false
        $validation.Errors += "Failed to validate commit conditions: $($_.Exception.Message)"
        return $validation
    }
}

<#
.SYNOPSIS
    Generates intelligent commit messages based on staged changes
    
.DESCRIPTION
    Analyzes staged changes to automatically generate meaningful commit messages
    using templates, patterns, and AI-like logic.
    
.PARAMETER StagedChanges
    Staged changes object from Get-StagedChanges
    
.PARAMETER Template
    Template to use for message generation
    
.EXAMPLE
    Get-CommitMessage -StagedChanges $changes -Template "feature"
#>
function Get-CommitMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$StagedChanges,
        
        [string]$Template
    )
    
    try {
        # Get configuration for message generation
        $config = Get-GitZoomConfig
        $messageConfig = $config.Commit.MessageGeneration
        
        if (-not $messageConfig.Enabled) {
            Write-Verbose "Auto message generation is disabled"
            return $null
        }
        
        # Analyze change patterns
        $analysis = Invoke-ChangeAnalysis -StagedChanges $StagedChanges
        
        # Select appropriate template
    $selectedTemplate = Select-MessageTemplate -Analysis $analysis -RequestedTemplate $Template -Config $messageConfig
        
        # Generate message based on analysis and template
    $message = Build-CommitMessage -Analysis $analysis -Template $selectedTemplate -Config $messageConfig
        
        Write-Verbose "Generated commit message: $message"
        return $message
    }
    catch {
        Write-Error "Failed to generate commit message: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
    Analyzes staged changes to understand the nature of modifications
    
.DESCRIPTION
    Performs pattern recognition on staged changes to categorize the type
    of work being committed (feature, fix, refactor, etc.).
    
.PARAMETER StagedChanges
    Staged changes object from Get-StagedChanges
    
.EXAMPLE
    Invoke-ChangeAnalysis -StagedChanges $changes
#>
function Invoke-ChangeAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$StagedChanges
    )
    
    $analysis = @{
        Type = "misc"
        Scope = @()
        Confidence = 0.0
        Keywords = @()
        FileTypes = @()
        Patterns = @()
    }
    
    try {
        $files = $StagedChanges.Files
        
        # Analyze file types and paths
        $fileAnalysis = Get-FileTypeAnalysis -Files $files
        $analysis.FileTypes = $fileAnalysis.Types
        $analysis.Scope = $fileAnalysis.Scopes
        
        # Pattern matching for change types
        $patterns = @{
            "feature" = @{
                Keywords = @("add", "new", "implement", "create", "introduce")
                FilePatterns = @("*feature*", "*component*", "*page*")
                Confidence = 0.8
            }
            "fix" = @{
                Keywords = @("fix", "bug", "error", "issue", "resolve", "correct")
                FilePatterns = @("*fix*", "*patch*", "*hotfix*")
                Confidence = 0.9
            }
            "refactor" = @{
                Keywords = @("refactor", "restructure", "reorganize", "cleanup", "optimize")
                FilePatterns = @("*refactor*")
                Confidence = 0.7
            }
            "docs" = @{
                Keywords = @("doc", "readme", "comment", "documentation")
                FilePatterns = @("*.md", "*.txt", "*doc*", "*readme*")
                Confidence = 0.9
            }
            "test" = @{
                Keywords = @("test", "spec", "unit", "integration", "coverage")
                FilePatterns = @("*test*", "*spec*", "__test__*", "*.test.*", "*.spec.*")
                Confidence = 0.9
            }
            "style" = @{
                Keywords = @("style", "format", "lint", "prettier", "css", "sass")
                FilePatterns = @("*.css", "*.scss", "*.less", "*style*")
                Confidence = 0.8
            }
            "config" = @{
                Keywords = @("config", "setting", "env", "environment")
                FilePatterns = @("*.config.*", "*.env*", "*config*", "package.json")
                Confidence = 0.8
            }
        }
        
        # Score each pattern type
        $scores = @{}
        foreach ($patternType in $patterns.Keys) {
            $pattern = $patterns[$patternType]
            $score = 0.0
            
            # Check file patterns
            foreach ($file in $files) {
                foreach ($filePattern in $pattern.FilePatterns) {
                    if ($file.Name -like $filePattern) {
                        $score += 0.3
                    }
                }
            }
            
            # Analyze commit content for keywords (would need diff analysis)
            # For now, use file names and paths
            $pathContent = ($files | ForEach-Object { $_.Name }) -join " "
            foreach ($keyword in $pattern.Keywords) {
                if ($pathContent -match $keyword) {
                    $score += 0.2
                }
            }
            
            # Apply confidence multiplier
            $scores[$patternType] = $score * $pattern.Confidence
        }
        
        # Select the highest scoring pattern
        $topPattern = $scores.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1
        
        if ($topPattern -and $topPattern.Value -gt 0.1) {
            $analysis.Type = $topPattern.Name
            $analysis.Confidence = $topPattern.Value
            $analysis.Patterns += $topPattern.Name
        }
        
        # Extract keywords from file names
        $commonWords = @("the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by")
        $words = ($files | ForEach-Object { 
            [System.IO.Path]::GetFileNameWithoutExtension($_.Name) -split '[^a-zA-Z0-9]' 
        }) | Where-Object { 
            $_.Length -gt 2 -and $_ -notin $commonWords 
        } | Group-Object | Sort-Object Count -Descending | Select-Object -First 5
        
        $analysis.Keywords = $words | ForEach-Object { $_.Name }
        
        Write-Verbose "Change analysis complete: Type=$($analysis.Type), Confidence=$($analysis.Confidence)"
        
        return $analysis
    }
    catch {
        Write-Error "Change analysis failed: $($_.Exception.Message)"
        return $analysis
    }
}

<#
.SYNOPSIS
    Optimizes commit messages for clarity and consistency
    
.DESCRIPTION
    Improves commit messages by applying formatting rules, checking conventions,
    and ensuring clarity and consistency with project standards.
    
.PARAMETER Message
    Original commit message to optimize
    
.PARAMETER StagedChanges
    Staged changes context for optimization
    
.EXAMPLE
    Optimize-CommitMessage -Message "fix bug" -StagedChanges $changes
#>
function Optimize-CommitMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter(Mandatory)]
        [hashtable]$StagedChanges
    )
    
    try {
        $config = Get-GitZoomConfig
        $optimizationConfig = $config.Commit.MessageOptimization
        
        if (-not $optimizationConfig.Enabled) {
            return $Message
        }
        
        $optimized = $Message.Trim()
        
        # Apply capitalization rules
        if ($optimizationConfig.CapitalizeFirst) {
            $optimized = $optimized.Substring(0, 1).ToUpper() + $optimized.Substring(1)
        }
        
        # Remove trailing periods if configured
        if ($optimizationConfig.RemoveTrailingPeriod -and $optimized.EndsWith('.')) {
            $optimized = $optimized.TrimEnd('.')
        }
        
        # Apply length limits
        $maxLength = $optimizationConfig.MaxSubjectLength
        if ($optimized.Length -gt $maxLength) {
            # Try to truncate at word boundary
            $truncated = $optimized.Substring(0, $maxLength)
            $lastSpace = $truncated.LastIndexOf(' ')
            if ($lastSpace -gt ($maxLength * 0.7)) {
                $optimized = $truncated.Substring(0, $lastSpace) + "..."
            }
            else {
                $optimized = $truncated + "..."
            }
        }
        
        # Add scope if configured and detected
        if ($optimizationConfig.AddScope -and $StagedChanges.Files.Count -gt 0) {
            $scope = Get-CommitScope -StagedChanges $StagedChanges
            if ($scope -and -not $optimized.StartsWith("${scope}:")) {
                $optimized = "$scope`: $optimized"
            }
        }
        
        # Apply conventional commit format if enabled
        if ($optimizationConfig.ConventionalCommits) {
            $optimized = Format-ConventionalCommit -Message $optimized -StagedChanges $StagedChanges
        }
        
        Write-Verbose "Message optimized: '$Message' -> '$optimized'"
        return $optimized
    }
    catch {
        Write-Error "Failed to optimize commit message: $($_.Exception.Message)"
        return $Message
    }
}

<#
.SYNOPSIS
    Executes the actual git commit operation
    
.DESCRIPTION
    Handles the low-level git commit execution with proper error handling
    and result parsing.
    
.PARAMETER Message
    Commit message to use
    
.PARAMETER Amend
    Amend the previous commit
    
.PARAMETER AllowEmpty
    Allow empty commits
    
.PARAMETER Interactive
    Use interactive commit mode
    
.EXAMPLE
    Invoke-GitCommit -Message "Fix authentication bug"
#>
function Invoke-GitCommit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [switch]$Amend,
        [switch]$AllowEmpty,
        [switch]$Interactive
    )
    
    $result = @{
        Success = $false
        Hash = $null
        Error = $null
    }
    
    try {
        $gitArgs = @("commit", "-m", $Message)
        
        if ($Amend) { $gitArgs += "--amend" }
        if ($AllowEmpty) { $gitArgs += "--allow-empty" }
        if ($Interactive) { $gitArgs += "--interactive" }
        
        Write-Verbose "Executing git commit with args: $($gitArgs -join ' ')"
        
        $output = & git @gitArgs 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $result.Success = $true
            
            # Extract commit hash from output
            if ($output -match '\[.*\s([a-f0-9]{7,})\]') {
                $result.Hash = $matches[1]
            }
            else {
                # Fallback to getting latest commit hash
                $result.Hash = git rev-parse HEAD 2>$null
            }
            
            Write-Verbose "Commit successful: $($result.Hash)"
        }
        else {
            $result.Error = $output -join "`n"
            Write-Verbose "Commit failed: $($result.Error)"
        }
    }
    catch {
        $result.Error = $_.Exception.Message
    }
    
    return $result
}

#endregion

#region Helper Functions

<#
.SYNOPSIS
    Gets current repository state information
#>
function Get-RepositoryState {
    $state = @{
        HasConflicts = $false
        RebaseInProgress = $false
        MergeInProgress = $false
        CurrentBranch = $null
    }
    
    try {
        # Check for conflicts
        $conflicts = git diff --name-only --diff-filter=U 2>$null
        $state.HasConflicts = $LASTEXITCODE -eq 0 -and $conflicts
        
        # Check for rebase
        $state.RebaseInProgress = Test-Path ".git/rebase-merge" -or Test-Path ".git/rebase-apply"
        
        # Check for merge
        $state.MergeInProgress = Test-Path ".git/MERGE_HEAD"
        
        # Get current branch
        $state.CurrentBranch = git branch --show-current 2>$null
    }
    catch {
        Write-Verbose "Could not determine repository state: $($_.Exception.Message)"
    }
    
    return $state
}

<#
.SYNOPSIS
    Adds commit metrics for performance tracking
#>
function Add-CommitMetric {
    param([hashtable]$Results)
    
    try {
        $metric = @{
            Timestamp = Get-Date
            Files = $Results.StagedFiles.Count
            Duration = $Results.Performance.TotalTime
            MessageLength = $Results.Performance.MessageLength
            Success = ($Results.Errors.Count -eq 0)
        }
        
        Add-PerformanceMetric -Operation "commit" -Metrics $metric
    }
    catch {
        Write-Verbose "Failed to record commit metrics: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Placeholder for post-commit operations
#>
function Invoke-PostCommitOperations {
    param(
        [string]$CommitHash,
        [array]$StagedFiles
    )
    
    # Future: Auto-push, notifications, hooks, etc.
    # StagedFiles parameter reserved for future use (e.g., selective notifications)
    Write-Verbose "Post-commit operations completed for $CommitHash with $($StagedFiles.Count) files"
}

#endregion

# Export functions
Export-ModuleMember -Function @(
    "Invoke-SmartCommit",
    "Get-StagedChanges",
    "Test-CommitConditions",
    "Get-CommitMessage",
    "Optimize-CommitMessage"
)