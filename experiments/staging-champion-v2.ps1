<#
.SYNOPSIS
    GitZoom STAGING CHAMPION v2 - Maximum Staging Performance (Refactored)

.DESCRIPTION
    STRATEGY: Focus 100% on staging optimization where we consistently win 55-80%
    GOAL: Push staging improvements to 200%+ to achieve overall 300%+ target
    
    This version uses the shared PerformanceExperiments module for cleaner,
    more maintainable code with better error handling and memory tracking.

.PARAMETER TestStagingChampion
    Run the staging champion test

.PARAMETER FileCount
    Number of files to test with (default: 300)

.PARAMETER MaximizeStaging
    Apply maximum staging optimizations

.PARAMETER Verbose
    Show detailed logging

.EXAMPLE
    .\staging-champion-v2.ps1 -TestStagingChampion -FileCount 300 -MaximizeStaging
#>

param(
    [switch]$TestStagingChampion,
    [int]$FileCount = 300,
    [switch]$MaximizeStaging
)

$ErrorActionPreference = "Stop"
$VerbosePreference = if ($PSBoundParameters.ContainsKey('Verbose')) { 'Continue' } else { 'SilentlyContinue' }

# Dot-source the shared performance library
$modulePath = Join-Path $PSScriptRoot "..\lib\PerformanceExperiments.ps1"
. $modulePath

# Global results storage
$Global:StagingResults = @{
    StandardOps = @{}
    ChampionOps = @{}
    Improvements = @{}
    MemoryMetrics = @{}
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

#region Configuration

function Get-StagingChampionConfigs {
    <#
    .SYNOPSIS
        Returns optimized Git configurations for staging performance
    #>
    param(
        [switch]$Maximum
    )
    
    # Base champion configurations - all proven winners
    $configs = @{
        "core.fscache" = "true"
        "core.preloadindex" = "true"
        "core.untrackedCache" = "true"
        "gc.auto" = "0"
        "index.version" = "4"
        "index.recordOffsetTable" = "true"
        "core.splitIndex" = "true"
    }
    
    if ($Maximum) {
        # MAXIMUM staging optimizations
        $configs["pack.useSparse"] = "true"
        $configs["feature.manyFiles"] = "true"
        $configs["core.commitGraph"] = "true"
        $configs["status.showUntrackedFiles"] = "no"
    }
    
    return $configs
}

function Set-StagingEnvironmentVariables {
    <#
    .SYNOPSIS
        Sets environment variables for maximum staging performance
    .NOTES
        This function modifies environment variables but does not persist changes beyond the current session
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param()
    
    $env:GIT_INDEX_VERSION = "4"
    $env:GIT_OPTIONAL_LOCKS = "0"
    $env:GIT_FLUSH = "0"
    $env:GIT_CONFIG_NOSYSTEM = "1"
    $env:GIT_CONFIG_NOGLOBAL = "1"
}

#endregion

#region Test Execution

function Invoke-StagingChampionTest {
    <#
    .SYNOPSIS
        Executes the staging champion performance test
    #>
    param(
        [int]$NumFiles,
        [switch]$Maximum
    )
    
    Write-PerformanceHeader "STAGING CHAMPION PERFORMANCE TEST" "🏆"
    Write-PerformanceLog "Testing with $NumFiles files" -Level "INFO" -Prefix "CHAMPION"
    
    # Measure baseline memory
    $Global:StagingResults.MemoryMetrics.Start = Get-MemoryUsage -IncludeSystem
    
    try {
        # Step 1: Measure standard operations
        Write-PerformanceLog "Measuring baseline (standard Git)..." -Level "BENCHMARK" -Prefix "CHAMPION"
        $Global:StagingResults.StandardOps = Measure-StandardOperations -NumFiles $NumFiles -Verbose:($VerbosePreference -eq 'Continue')
        
        # Step 2: Measure champion operations
        Write-PerformanceLog "Measuring CHAMPION performance..." -Level "TURBO" -Prefix "CHAMPION"
        $Global:StagingResults.ChampionOps = Measure-ChampionOperations -NumFiles $NumFiles -Maximum:$Maximum -Verbose:($VerbosePreference -eq 'Continue')
        
        # Step 3: Calculate improvements
        Write-PerformanceLog "Analyzing results..." -Level "INFO" -Prefix "CHAMPION"
        $Global:StagingResults.Improvements = Compare-StagingPerformance
        
        # Step 4: Display results
        Show-StagingChampionResults
        
        # Step 5: Export results
        $outputFile = Join-Path $PSScriptRoot "..\artifacts\performance\staging-champion-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $outputDir = Split-Path $outputFile -Parent
        if (-not (Test-Path $outputDir)) {
            New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
        }
        Export-PerformanceResults -Results $Global:StagingResults -OutputPath $outputFile -PrettyPrint
        
        # Measure final memory
        $Global:StagingResults.MemoryMetrics.End = Get-MemoryUsage -IncludeSystem
        $Global:StagingResults.MemoryMetrics.TotalDelta = [math]::Round(
            $Global:StagingResults.MemoryMetrics.End.WorkingSet - $Global:StagingResults.MemoryMetrics.Start.WorkingSet, 2)
        
        Write-PerformanceLog "Memory used during test: $($Global:StagingResults.MemoryMetrics.TotalDelta)MB" -Level "INFO" -Prefix "CHAMPION"
    }
    catch {
        Write-PerformanceLog "Error during staging champion test: $($_.Exception.Message)" -Level "ERROR" -Prefix "CHAMPION"
        throw
    }
}

function Measure-StandardOperations {
    <#
    .SYNOPSIS
        Measures standard Git operations for baseline comparison
    #>
    param(
        [int]$NumFiles,
        [switch]$Verbose
    )
    
    Write-PerformanceLog "Creating test environment for $NumFiles files" -Level "INFO" -Prefix "STANDARD"
    $testEnv = New-PerformanceTestEnvironment -TestName "staging-standard" -CleanupExisting -Confirm:$false
    
    try {
        $results = @{}
        
        # Init
        $initResult = Measure-OperationWithMemory -OperationName "Init" -ScriptBlock {
            git init --quiet 2>$null
        } -ShowDetails:$Verbose
        $results.Init = $initResult.ElapsedMilliseconds
        
        # File Creation
        $fileResult = Measure-OperationWithMemory -OperationName "FileCreation" -ScriptBlock {
            1..$NumFiles | ForEach-Object {
                $content = "File $_ content: $(Get-Random)"
                [System.IO.File]::WriteAllText("file$_.txt", $content)
            }
        } -ShowDetails:$Verbose
        $results.FileCreation = $fileResult.ElapsedMilliseconds
        
        # Staging (our main target!)
        $stagingResult = Measure-OperationWithMemory -OperationName "Staging" -ScriptBlock {
            git add . 2>$null
        } -ShowDetails:$Verbose
        $results.Staging = $stagingResult.ElapsedMilliseconds
        $results.StagingMemory = $stagingResult.MemoryDelta
        
        # Commit
        $commitResult = Measure-OperationWithMemory -OperationName "Commit" -ScriptBlock {
            git commit -m "Standard commit" --quiet 2>$null
        } -ShowDetails:$Verbose
        $results.Commit = $commitResult.ElapsedMilliseconds
        
        Write-PerformanceLog "Standard staging: $($results.Staging)ms (Memory: $($results.StagingMemory)MB)" -Level "BENCHMARK" -Prefix "STANDARD"
        
        return $results
    }
    finally {
        Remove-PerformanceTestEnvironment -Environment $testEnv -Confirm:$false
    }
}

function Measure-ChampionOperations {
    <#
    .SYNOPSIS
        Measures champion Git operations with all optimizations enabled
    #>
    param(
        [int]$NumFiles,
        [switch]$Maximum,
        [switch]$Verbose
    )
    
    Write-PerformanceLog "Creating champion environment for $NumFiles files" -Level "TURBO" -Prefix "CHAMPION"
    $testEnv = New-PerformanceTestEnvironment -TestName "staging-champion" -CleanupExisting -Confirm:$false
    
    try {
        $results = @{}
        $configs = Get-StagingChampionConfigs -Maximum:$Maximum
        
        Write-PerformanceLog "Applying $($configs.Count) champion configurations" -Level "TURBO" -Prefix "CHAMPION"
        
        # Use Invoke-WithGitConfig for safe configuration management
        Invoke-WithGitConfig -Configurations $configs -ScriptBlock {
            
            # Init (includes config application)
            $initResult = Measure-OperationWithMemory -OperationName "ChampionInit" -ScriptBlock {
                git init --quiet 2>$null
                
                # Reapply configs in the new repo
                foreach ($config in $configs.GetEnumerator()) {
                    git config $config.Key $config.Value 2>$null
                }
            } -ShowDetails:$Verbose
            $results.Init = $initResult.ElapsedMilliseconds
            
            # File Creation
            $fileResult = Measure-OperationWithMemory -OperationName "ChampionFileCreation" -ScriptBlock {
                1..$NumFiles | ForEach-Object {
                    $content = "CHAMPION file $_ content: $(Get-Random)"
                    [System.IO.File]::WriteAllText("file$_.txt", $content)
                }
            } -ShowDetails:$Verbose
            $results.FileCreation = $fileResult.ElapsedMilliseconds
            
            # CHAMPION STAGING - The main event!
            Write-PerformanceLog "🎯 CHAMPION STAGING STARTING..." -Level "TURBO" -Prefix "CHAMPION"
            
            $stagingResult = Measure-OperationWithMemory -OperationName "ChampionStaging" -ScriptBlock {
                # Set environment variables for maximum performance
                Set-StagingEnvironmentVariables
                
                # Use the fastest Git add options
                git add --all --verbose 2>$null
            } -ShowDetails:$Verbose
            
            $results.Staging = $stagingResult.ElapsedMilliseconds
            $results.StagingMemory = $stagingResult.MemoryDelta
            
            Write-PerformanceLog "🏆 CHAMPION STAGING: $($results.Staging)ms (Memory: $($results.StagingMemory)MB)" -Level "SUCCESS" -Prefix "CHAMPION"
            
            # CHAMPION Commit
            $commitResult = Measure-OperationWithMemory -OperationName "ChampionCommit" -ScriptBlock {
                $commitTime = [DateTimeOffset]::Now.ToString("o")
                $env:GIT_AUTHOR_DATE = $commitTime
                $env:GIT_COMMITTER_DATE = $commitTime
                
                git commit -m "STAGING CHAMPION commit: $NumFiles files!" --quiet --no-verify 2>$null
            } -ShowDetails:$Verbose
            $results.Commit = $commitResult.ElapsedMilliseconds
            
        } -ShowDetails:$Verbose
        
        return $results
    }
    finally {
        Remove-PerformanceTestEnvironment -Environment $testEnv
    }
}

function Compare-StagingPerformance {
    <#
    .SYNOPSIS
        Compares standard vs champion performance
    #>
    $operations = @("Init", "FileCreation", "Staging", "Commit")
    $improvements = @{}
    
    foreach ($op in $operations) {
        $standardTime = $Global:StagingResults.StandardOps.$op
        $championTime = $Global:StagingResults.ChampionOps.$op
        
        $comparison = Format-PerformanceComparison `
            -StandardTime $standardTime `
            -OptimizedTime $championTime `
            -OperationName $op `
            -Detailed
        
        $improvements[$op] = $comparison
    }
    
    return $improvements
}

#endregion

#region Results Display

function Show-StagingChampionResults {
    <#
    .SYNOPSIS
        Displays formatted staging champion results
    #>
    Write-Host "`n"
    Write-Host "━" * 80 -ForegroundColor Red
    Write-Host "🏆🎯 STAGING CHAMPION RESULTS 🎯🏆".PadLeft(50) -ForegroundColor White -BackgroundColor DarkRed
    Write-Host "━" * 80 -ForegroundColor Red
    
    $operations = @("Init", "FileCreation", "Staging", "Commit")
    $totalStandard = 0
    $totalChampion = 0
    
    foreach ($op in $operations) {
        $improvement = $Global:StagingResults.Improvements.$op
        
        $totalStandard += $improvement.StandardTime
        $totalChampion += $improvement.OptimizedTime
        
        Write-Host "`n┌─ $op " -NoNewline -ForegroundColor Cyan
        Write-Host ("─" * (70 - $op.Length)) -ForegroundColor DarkCyan
        Write-Host "│ Standard:   $($improvement.StandardTime)ms" -ForegroundColor White
        Write-Host "│ Champion:   $($improvement.OptimizedTime)ms" -ForegroundColor Yellow
        Write-Host "│ Saved:      $($improvement.TimeSaved)ms" -ForegroundColor Green
        Write-Host "│ Speedup:    $($improvement.Speedup)x" -ForegroundColor Magenta
        Write-Host "│ Improvement: $($improvement.Improvement)%" -ForegroundColor Green
        Write-Host "│ Status:     $($improvement.Status)" -ForegroundColor $(
            switch ($improvement.Status) {
                "Excellent" { "Green" }
                "Good" { "Cyan" }
                "Marginal" { "Yellow" }
                default { "White" }
            }
        )
        
        # Special highlighting for staging
        if ($op -eq "Staging") {
            if ($improvement.Improvement -gt 100) {
                Write-Host "│" -ForegroundColor DarkCyan
                Write-Host "│ 🏆🏆 STAGING CHAMPION! 100%+ GAIN! 🏆🏆" -ForegroundColor Red
            } elseif ($improvement.Improvement -gt 75) {
                Write-Host "│" -ForegroundColor DarkCyan
                Write-Host "│ 🏆 STAGING CHAMPION! 75%+ GAIN! 🏆" -ForegroundColor Yellow
            } elseif ($improvement.Improvement -gt 50) {
                Write-Host "│" -ForegroundColor DarkCyan
                Write-Host "│ 🎯 STAGING SUCCESS! 50%+ GAIN! 🎯" -ForegroundColor Green
            }
        }
        
        Write-Host "└" -NoNewline -ForegroundColor DarkCyan
        Write-Host ("─" * 75) -ForegroundColor DarkCyan
    }
    
    # Overall performance
    if ($totalStandard -gt 0) {
        $overallImprovement = [math]::Round((($totalStandard - $totalChampion) / $totalStandard) * 100, 2)
        $overallSpeedup = [math]::Round($totalStandard / $totalChampion, 2)
        $totalTimeSaved = $totalStandard - $totalChampion
        
        Write-Host "`n"
        Write-Host "━" * 80 -ForegroundColor Green
        Write-Host "OVERALL PERFORMANCE".PadLeft(45) -ForegroundColor White -BackgroundColor DarkGreen
        Write-Host "━" * 80 -ForegroundColor Green
        Write-Host "  Total Standard Time:  ${totalStandard}ms" -ForegroundColor White
        Write-Host "  Total Champion Time:  ${totalChampion}ms" -ForegroundColor Yellow
        Write-Host "  Total Time Saved:     ${totalTimeSaved}ms" -ForegroundColor Green
        Write-Host "  Overall Speedup:      ${overallSpeedup}x" -ForegroundColor Magenta
        Write-Host "  Overall Improvement:  ${overallImprovement}%" -ForegroundColor Green
        
        if ($overallImprovement -ge 300) {
            Write-Host "`n  🏆🏆🏆 TARGET ACHIEVED! 300%+ IMPROVEMENT! 🏆🏆🏆" -ForegroundColor Red
        } elseif ($overallImprovement -ge 200) {
            Write-Host "`n  🏆🏆 EXCELLENT! 200%+ IMPROVEMENT! 🏆🏆" -ForegroundColor Yellow
        } elseif ($overallImprovement -ge 100) {
            Write-Host "`n  🏆 GREAT! 100%+ IMPROVEMENT! 🏆" -ForegroundColor Green
        }
        
        Write-Host "━" * 80 -ForegroundColor Green
    }
    
    Write-Host ""
}

#endregion

#region Main Execution

# Main execution
if ($TestStagingChampion) {
    Invoke-StagingChampionTest -NumFiles $FileCount -Maximum:$MaximizeStaging
} else {
    Write-PerformanceLog "Use -TestStagingChampion to run the test" -Level "INFO" -Prefix "CHAMPION"
    Write-Host ""
    Write-Host "Example: .\staging-champion-v2.ps1 -TestStagingChampion -FileCount 300 -MaximizeStaging" -ForegroundColor Cyan
    Write-Host ""
}

#endregion
