#requires -version 5.1

<#
.SYNOPSIS
    GitZoom - Lightning-Fast Git Operations for Windows
    
.DESCRIPTION
    GitZoom is a high-performance PowerShell module that supercharges Git operations
    on Windows systems through intelligent optimizations, batch processing, and 
    Windows-specific enhancements.
    
.AUTHOR
    GitZoom Team
    
.VERSION
    1.0.0
#>

# Module Variables
$Script:GitZoomConfig = @{}
$Script:PerformanceMetrics = @{
    Operations = @{}
    TotalTime = 0
    OperationCount = 0
}

# Import performance measurement function
. "$PSScriptRoot\Performance.ps1"
. "$PSScriptRoot\Configuration.ps1"
. "$PSScriptRoot\Staging.ps1"
. "$PSScriptRoot\Commit.ps1"
. "$PSScriptRoot\Utilities.ps1"

#region Core Functions

<#
.SYNOPSIS
    Initializes GitZoom for the current repository
    
.DESCRIPTION
    Sets up GitZoom configuration and optimizations for the current Git repository.
    This should be called once per repository to enable GitZoom features.
    
.PARAMETER Path
    The path to the Git repository. Defaults to current directory.
    
.PARAMETER Force
    Force re-initialization even if GitZoom is already configured.
    
.EXAMPLE
    Initialize-GitZoom
    
.EXAMPLE
    Initialize-GitZoom -Path "C:\MyProject" -Force
#>
function Initialize-GitZoom {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Path = (Get-Location),
        
        [switch]$Force
    )
    
    begin {
        Write-Verbose "Initializing GitZoom for repository at: $Path"
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    }
    
    process {
        try {
            # Validate Git repository
            Push-Location $Path
            $gitRoot = git rev-parse --show-toplevel 2>$null
            if (-not $gitRoot -or $LASTEXITCODE -ne 0) {
                throw "Not a valid Git repository: $Path"
            }
            
            # Check if already initialized
            $gitZoomFile = Join-Path $gitRoot ".gitzoom"
            if ((Test-Path $gitZoomFile) -and -not $Force) {
                Write-Host "✅ GitZoom already initialized for this repository" -ForegroundColor Green
                return
            }
            
            # Create GitZoom configuration
            $config = @{
                Version = "1.0.0"
                InitializedAt = Get-Date
                Repository = $gitRoot
                Features = @{
                    BatchOperations = $true
                    IntelligentStaging = $true
                    PerformanceTracking = $true
                    OptimizedCommits = $true
                }
                Performance = @{
                    MaxFileThreshold = 100
                    BatchSize = 50
                    TimeoutSeconds = 30
                }
            }
            
            # Save configuration
            $config | ConvertTo-Json -Depth 3 | Set-Content $gitZoomFile -Encoding UTF8
            
            # Initialize global performance tracking
            Initialize-PerformanceTracking
            
            # Set up Git optimizations
            Set-GitOptimizations
            
            Write-Host "🚀 GitZoom initialized successfully!" -ForegroundColor Green
            Write-Host "   Repository: $gitRoot" -ForegroundColor Cyan
            Write-Host "   Features: Batch Operations, Intelligent Staging, Performance Tracking" -ForegroundColor Cyan
            
        }
        catch {
            Write-Error "Failed to initialize GitZoom: $($_.Exception.Message)"
            throw
        }
        finally {
            Pop-Location
            $stopwatch.Stop()
            Add-PerformanceMetric -Operation "Initialize-GitZoom" -Duration $stopwatch.ElapsedMilliseconds
        }
    }
}

<#
.SYNOPSIS
    Gets the current GitZoom status and performance metrics
    
.DESCRIPTION
    Displays comprehensive information about GitZoom's current state,
    including configuration, performance metrics, and repository status.
    
.PARAMETER ShowMetrics
    Include detailed performance metrics in the output.
    
.PARAMETER ShowConfig
    Include configuration details in the output.
    
.EXAMPLE
    Get-GitZoomStatus
    
.EXAMPLE
    Get-GitZoomStatus -ShowMetrics -ShowConfig
#>
function Get-GitZoomStatus {
    [CmdletBinding()]
    param(
        [switch]$ShowMetrics,
        [switch]$ShowConfig
    )
    
    begin {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    }
    
    process {
        try {
            # Check if in Git repository
            $gitRoot = git rev-parse --show-toplevel 2>$null
            if (-not $gitRoot -or $LASTEXITCODE -ne 0) {
                Write-Warning "Not in a Git repository"
                return
            }
            
            # Check GitZoom initialization
            $gitZoomFile = Join-Path $gitRoot ".gitzoom"
            if (-not (Test-Path $gitZoomFile)) {
                Write-Host "❌ GitZoom not initialized for this repository" -ForegroundColor Red
                Write-Host "   Run 'Initialize-GitZoom' to set up GitZoom" -ForegroundColor Yellow
                return
            }
            
            # Load configuration
            $config = Get-Content $gitZoomFile | ConvertFrom-Json
            
            # Display status
            Write-Host ""
            Write-Host "⚡ GitZoom Status" -ForegroundColor Magenta
            Write-Host "=" * 50 -ForegroundColor DarkGray
            Write-Host "Version: $($config.Version)" -ForegroundColor Green
            Write-Host "Repository: $gitRoot" -ForegroundColor Cyan
            Write-Host "Initialized: $($config.InitializedAt)" -ForegroundColor Gray
            
            # Git status
            $gitStatus = git status --porcelain 2>$null
            $changedFiles = @($gitStatus).Count
            Write-Host "Changed Files: $changedFiles" -ForegroundColor $(if ($changedFiles -gt 0) { "Yellow" } else { "Green" })
            
            # Features status
            Write-Host ""
            Write-Host "🚀 Features:" -ForegroundColor Blue
            foreach ($feature in $config.Features.PSObject.Properties) {
                $status = if ($feature.Value) { "✅ Enabled" } else { "❌ Disabled" }
                $color = if ($feature.Value) { "Green" } else { "Red" }
                Write-Host "   $($feature.Name): $status" -ForegroundColor $color
            }
            
            # Performance metrics
            if ($ShowMetrics -and $Script:PerformanceMetrics.OperationCount -gt 0) {
                Write-Host ""
                Write-Host "📊 Performance Metrics:" -ForegroundColor Blue
                Write-Host "   Total Operations: $($Script:PerformanceMetrics.OperationCount)" -ForegroundColor Cyan
                Write-Host "   Total Time: $([math]::Round($Script:PerformanceMetrics.TotalTime, 2))ms" -ForegroundColor Cyan
                Write-Host "   Average Time: $([math]::Round($Script:PerformanceMetrics.TotalTime / $Script:PerformanceMetrics.OperationCount, 2))ms" -ForegroundColor Cyan
                
                if ($Script:PerformanceMetrics.Operations.Count -gt 0) {
                    Write-Host "   Recent Operations:" -ForegroundColor Gray
                    $Script:PerformanceMetrics.Operations.GetEnumerator() | 
                        Sort-Object { $_.Value.LastExecuted } -Descending |
                        Select-Object -First 5 |
                        ForEach-Object {
                            $avgTime = [math]::Round($_.Value.TotalTime / $_.Value.Count, 2)
                            Write-Host "     $($_.Key): ${avgTime}ms (${($_.Value.Count)} calls)" -ForegroundColor DarkGray
                        }
                }
            }
            
            # Configuration details
            if ($ShowConfig) {
                Write-Host ""
                Write-Host "⚙️ Configuration:" -ForegroundColor Blue
                Write-Host "   Max File Threshold: $($config.Performance.MaxFileThreshold)" -ForegroundColor Cyan
                Write-Host "   Batch Size: $($config.Performance.BatchSize)" -ForegroundColor Cyan
                Write-Host "   Timeout: $($config.Performance.TimeoutSeconds)s" -ForegroundColor Cyan
            }
            
            Write-Host ""
        }
        catch {
            Write-Error "Failed to get GitZoom status: $($_.Exception.Message)"
        }
        finally {
            $stopwatch.Stop()
            Add-PerformanceMetric -Operation "Get-GitZoomStatus" -Duration $stopwatch.ElapsedMilliseconds
        }
    }
}

<#
.SYNOPSIS
    Performs a lightning-fast Git add operation
    
.DESCRIPTION
    Optimized file staging using intelligent batching, pattern recognition,
    and Windows-specific optimizations for maximum performance.
    
.PARAMETER Path
    Files or patterns to add. Supports wildcards and multiple paths.
    
.PARAMETER All
    Add all modified and new files.
    
.PARAMETER Force
    Force add files that would normally be ignored.
    
.PARAMETER Batch
    Override default batch processing settings.
    
.EXAMPLE
    Add-GitZoomFile "*.js"
    
.EXAMPLE
    Add-GitZoomFile -All
    
.EXAMPLE
    Add-GitZoomFile "src/", "docs/" -Force
#>
function Add-GitZoomFile {
    [CmdletBinding(DefaultParameterSetName = "Path")]
    [Alias("gza")]
    param(
        [Parameter(Position = 0, ParameterSetName = "Path", ValueFromPipeline = $true)]
        [string[]]$Path,
        
        [Parameter(ParameterSetName = "All")]
        [switch]$All,
        
        [switch]$Force,
        [switch]$Batch
    )
    
    begin {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $addedFiles = @()
        $errors = @()
    }
    
    process {
        try {
            if ($All) {
                Write-Verbose "Adding all modified and new files..."
                $result = Invoke-OptimizedStaging -All -Force:$Force -Batch:$Batch
            }
            else {
                Write-Verbose "Adding specified paths: $($Path -join ', ')"
                $result = Invoke-OptimizedStaging -Path $Path -Force:$Force -Batch:$Batch
            }
            
            $addedFiles += $result.AddedFiles
            $errors += $result.Errors
            
        }
        catch {
            $errors += $_.Exception.Message
            Write-Error "Failed to add files: $($_.Exception.Message)"
        }
    }
    
    end {
        $stopwatch.Stop()
        
        # Report results
        if ($addedFiles.Count -gt 0) {
            Write-Host "✅ Added $($addedFiles.Count) files" -ForegroundColor Green
            if ($VerbosePreference -eq "Continue") {
                $addedFiles | ForEach-Object { Write-Host "   + $_" -ForegroundColor DarkGreen }
            }
        }
        
        if ($errors.Count -gt 0) {
            Write-Warning "Encountered $($errors.Count) errors during staging"
            $errors | ForEach-Object { Write-Warning "   $_" }
        }
        
        # Performance tracking
        Add-PerformanceMetric -Operation "Add-GitZoomFile" -Duration $stopwatch.ElapsedMilliseconds
        
        Write-Verbose "Operation completed in $($stopwatch.ElapsedMilliseconds)ms"
    }
}

<#
.SYNOPSIS
    Performs a lightning-fast Git commit operation
    
.DESCRIPTION
    Optimized commit operation with intelligent message processing,
    performance tracking, and advanced error handling.
    
.PARAMETER Message
    Commit message. If not provided, will open default editor.
    
.PARAMETER All
    Automatically stage all modified files before committing.
    
.PARAMETER Amend
    Amend the previous commit.
    
.PARAMETER NoVerify
    Skip pre-commit and commit-msg hooks.
    
.PARAMETER SuperFast
    Enable maximum performance optimizations.
    
.EXAMPLE
    Invoke-GitZoomCommit -Message "feat: Add new feature"
    
.EXAMPLE
    Invoke-GitZoomCommit -All -Message "fix: Bug fixes" -SuperFast
    
.EXAMPLE
    Invoke-GitZoomCommit -Amend -NoVerify
#>
function Invoke-GitZoomCommit {
    [CmdletBinding()]
    [Alias("gzc")]
    param(
        [Parameter(Position = 0)]
        [string]$Message,
        
        [switch]$All,
        [switch]$Amend,
        [switch]$NoVerify,
        [switch]$SuperFast
    )
    
    begin {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    }
    
    process {
        try {
            # Auto-stage if requested
            if ($All) {
                Write-Verbose "Auto-staging all files..."
                Add-GitZoomFile -All
            }
            
            # Perform optimized commit
            $result = Invoke-OptimizedCommit -Message $Message -Amend:$Amend -NoVerify:$NoVerify -SuperFast:$SuperFast
            
            if ($result.Success) {
                Write-Host "✅ Commit successful" -ForegroundColor Green
                Write-Host "   Hash: $($result.CommitHash)" -ForegroundColor Cyan
                Write-Host "   Files: $($result.FilesChanged)" -ForegroundColor Cyan
                
                if ($result.PerformanceGain -gt 0) {
                    Write-Host "   Performance: $([math]::Round($result.PerformanceGain, 1))% faster than standard Git" -ForegroundColor Yellow
                }
            }
            else {
                Write-Error "Commit failed: $($result.Error)"
            }
        }
        catch {
            Write-Error "Failed to commit: $($_.Exception.Message)"
            throw
        }
        finally {
            $stopwatch.Stop()
            Add-PerformanceMetric -Operation "Invoke-GitZoomCommit" -Duration $stopwatch.ElapsedMilliseconds
        }
    }
}

#endregion

#region Aliases and Shortcuts

# Main GitZoom commands
Set-Alias -Name "gzoom" -Value "Get-GitZoomStatus"
Set-Alias -Name "gzinit" -Value "Initialize-GitZoom"

# Git operation shortcuts
Set-Alias -Name "gzadd" -Value "Add-GitZoomFile"
Set-Alias -Name "gzcommit" -Value "Invoke-GitZoomCommit"

# Convenience combinations
function Invoke-GitZoomQuickCommit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Message
    )
    
    Add-GitZoomFile -All
    Invoke-GitZoomCommit -Message $Message -SuperFast
}
Set-Alias -Name "gzq" -Value "Invoke-GitZoomQuickCommit"

#endregion

# Export module members
Export-ModuleMember -Function @(
    "Initialize-GitZoom",
    "Get-GitZoomStatus", 
    "Add-GitZoomFile",
    "Invoke-GitZoomCommit",
    "Invoke-GitZoomQuickCommit"
) -Alias @(
    "gzoom", "gzinit", "gza", "gzc", "gzadd", "gzcommit", "gzq"
)

# Module initialization
Write-Host "⚡ GitZoom Module Loaded" -ForegroundColor Magenta
Write-Host "   Run 'gzinit' to initialize GitZoom in your repository" -ForegroundColor Cyan
Write-Host "   Run 'gzoom' to check status and performance metrics" -ForegroundColor Cyan