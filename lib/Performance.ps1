<#
.SYNOPSIS
    GitZoom Performance Measurement and Optimization Module
    
.DESCRIPTION
    Provides high-precision performance measurement, optimization detection,
    and performance tracking capabilities for GitZoom operations.
#>

#region Performance Measurement

<#
.SYNOPSIS
    Measures the execution time of a script block with high precision
    
.DESCRIPTION
    Executes a script block and measures its performance using high-resolution
    timers. Includes error handling and result capturing.
    
.PARAMETER Name
    Name of the operation being measured
    
.PARAMETER ScriptBlock
    The script block to execute and measure
    
.PARAMETER Silent
    Suppress output during execution
    
.EXAMPLE
    Measure-GitZoomOperation "File Staging" { git add . }
#>
function Measure-GitZoomOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [switch]$Silent
    )
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $result = $null
    $errorMessage = $null
    
    try {
        if ($Silent) {
            $result = & $ScriptBlock 2>$null
        }
        else {
            $result = & $ScriptBlock
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Verbose "Error in ${Name}: $errorMessage"
    }
    finally {
        $stopwatch.Stop()
        Add-PerformanceMetric -Operation $Name -Duration $stopwatch.ElapsedMilliseconds -Success:(-not $errorMessage)
    }
    
    return @{
        Result = $result
        Duration = $stopwatch.ElapsedMilliseconds
        Success = (-not $errorMessage)
        Error = $errorMessage
    }
}

<#
.SYNOPSIS
    Adds a performance metric to the tracking system
    
.DESCRIPTION
    Records performance data for analysis and optimization tracking.
    Maintains running averages and performance trends.
    
.PARAMETER Operation
    Name of the operation
    
.PARAMETER Duration
    Duration in milliseconds
    
.PARAMETER Success
    Whether the operation was successful
    
.EXAMPLE
    Add-PerformanceMetric -Operation "git-add" -Duration 150 -Success $true
#>
function Add-PerformanceMetric {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Operation,
        
        [Parameter(Mandatory)]
        [double]$Duration,
        
        [bool]$Success = $true
    )
    
    if (-not $Script:PerformanceMetrics.Operations.ContainsKey($Operation)) {
        $Script:PerformanceMetrics.Operations[$Operation] = @{
            Count = 0
            TotalTime = 0
            AverageTime = 0
            MinTime = [double]::MaxValue
            MaxTime = 0
            LastExecuted = Get-Date
            SuccessRate = 0
            Failures = 0
        }
    }
    
    $metric = $Script:PerformanceMetrics.Operations[$Operation]
    $metric.Count++
    $metric.TotalTime += $Duration
    $metric.AverageTime = $metric.TotalTime / $metric.Count
    $metric.MinTime = [Math]::Min($metric.MinTime, $Duration)
    $metric.MaxTime = [Math]::Max($metric.MaxTime, $Duration)
    $metric.LastExecuted = Get-Date
    
    if (-not $Success) {
        $metric.Failures++
    }
    $metric.SuccessRate = (($metric.Count - $metric.Failures) / $metric.Count) * 100
    
    # Update global metrics
    $Script:PerformanceMetrics.OperationCount++
    $Script:PerformanceMetrics.TotalTime += $Duration
}

<#
.SYNOPSIS
    Initializes the performance tracking system
    
.DESCRIPTION
    Sets up performance monitoring and resets all metrics.
    Called automatically when GitZoom is initialized.
#>
function Initialize-PerformanceTracking {
    [CmdletBinding()]
    param()
    
    $Script:PerformanceMetrics = @{
        Operations = @{}
        TotalTime = 0
        OperationCount = 0
        StartTime = Get-Date
        Baseline = @{}
    }
    
    Write-Verbose "Performance tracking initialized"
}

<#
.SYNOPSIS
    Compares performance against baseline Git operations
    
.DESCRIPTION
    Measures the performance difference between GitZoom optimizations
    and standard Git commands to calculate performance improvements.
    
.PARAMETER Operation
    The Git operation to benchmark
    
.PARAMETER GitZoomTime
    Time taken by GitZoom operation
    
.PARAMETER StandardGitTime
    Time taken by standard Git operation (if available)
    
.EXAMPLE
    Compare-PerformanceGain -Operation "add" -GitZoomTime 50 -StandardGitTime 120
#>
function Compare-PerformanceGain {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Operation,
        
        [Parameter(Mandatory)]
        [double]$GitZoomTime,
        
        [double]$StandardGitTime
    )
    
    if ($StandardGitTime -gt 0) {
        $improvement = (($StandardGitTime - $GitZoomTime) / $StandardGitTime) * 100
        
        # Store baseline for future comparisons
        if (-not $Script:PerformanceMetrics.Baseline.ContainsKey($Operation)) {
            $Script:PerformanceMetrics.Baseline[$Operation] = @{
                StandardTime = $StandardGitTime
                BestGitZoomTime = $GitZoomTime
                AverageImprovement = $improvement
            }
        }
        else {
            $baseline = $Script:PerformanceMetrics.Baseline[$Operation]
            $baseline.BestGitZoomTime = [Math]::Min($baseline.BestGitZoomTime, $GitZoomTime)
            
            # Update average improvement
            $baseline.AverageImprovement = (($baseline.StandardTime - $baseline.BestGitZoomTime) / $baseline.StandardTime) * 100
        }
        
        return $improvement
    }
    
    return 0
}

<#
.SYNOPSIS
    Gets comprehensive performance statistics
    
.DESCRIPTION
    Returns detailed performance metrics including operation summaries,
    trends, and performance improvements over standard Git.
    
.PARAMETER Operation
    Specific operation to get stats for (optional)
    
.EXAMPLE
    Get-PerformanceStats
    
.EXAMPLE
    Get-PerformanceStats -Operation "Add-GitZoomFile"
#>
function Get-PerformanceStats {
    [CmdletBinding()]
    param(
        [string]$Operation
    )
    
    if ($Operation) {
        if ($Script:PerformanceMetrics.Operations.ContainsKey($Operation)) {
            return $Script:PerformanceMetrics.Operations[$Operation]
        }
        else {
            Write-Warning "No performance data found for operation: $Operation"
            return $null
        }
    }
    
    # Return comprehensive stats
    $stats = @{
        Summary = @{
            TotalOperations = $Script:PerformanceMetrics.OperationCount
            TotalTime = $Script:PerformanceMetrics.TotalTime
            AverageTime = if ($Script:PerformanceMetrics.OperationCount -gt 0) { 
                $Script:PerformanceMetrics.TotalTime / $Script:PerformanceMetrics.OperationCount 
            } else { 0 }
            SessionDuration = ((Get-Date) - $Script:PerformanceMetrics.StartTime).TotalMinutes
        }
        Operations = $Script:PerformanceMetrics.Operations
        Baselines = $Script:PerformanceMetrics.Baseline
        TopPerformers = @()
    }
    
    # Calculate top performing operations
    if ($Script:PerformanceMetrics.Operations.Count -gt 0) {
        $stats.TopPerformers = $Script:PerformanceMetrics.Operations.GetEnumerator() |
            Sort-Object { $_.Value.AverageTime } |
            Select-Object -First 5 |
            ForEach-Object {
                @{
                    Operation = $_.Key
                    AverageTime = [math]::Round($_.Value.AverageTime, 2)
                    Count = $_.Value.Count
                    SuccessRate = [math]::Round($_.Value.SuccessRate, 1)
                }
            }
    }
    
    return $stats
}

#endregion

#region Git Optimizations

<#
.SYNOPSIS
    Applies Git configuration optimizations for better performance
    
.DESCRIPTION
    Configures Git settings that improve performance on Windows systems.
    These optimizations are automatically applied when GitZoom is initialized.
#>
function Set-GitOptimizations {
    [CmdletBinding()]
    param()
    
    try {
        Write-Verbose "Applying Git performance optimizations..."
        
        # Core optimizations
        git config core.preloadindex true 2>$null
        git config core.fscache true 2>$null
        git config gc.auto 256 2>$null
        
        # Windows-specific optimizations
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            git config core.autocrlf true 2>$null
            git config core.longpaths true 2>$null
            git config core.symlinks false 2>$null
        }
        
        # Performance optimizations
        git config status.showUntrackedFiles normal 2>$null
        git config diff.algorithm histogram 2>$null
        
        Write-Verbose "Git optimizations applied successfully"
    }
    catch {
        Write-Warning "Some Git optimizations could not be applied: $($_.Exception.Message)"
    }
}

#endregion

# Export functions (handled by module manifest)
# Export-ModuleMember -Function @(
#     "Measure-GitZoomOperation",
#     "Add-PerformanceMetric", 
#     "Initialize-PerformanceTracking",
#     "Compare-PerformanceGain",
#     "Get-PerformanceStats",
#     "Set-GitOptimizations"
# )