<#
.SYNOPSIS
    Shared Performance Measurement Library for GitZoom Experiments

.DESCRIPTION
    Common functions and utilities for all GitZoom performance experiments.
    Provides consistent measurement, logging, Git config management, and result formatting.

.NOTES
    Author: GitZoom Team
    Date: October 11, 2025
    Version: 1.0.0
#>

#region Logging Functions

function Write-PerformanceLog {
    <#
    .SYNOPSIS
        Standardized logging with color coding and timestamps
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "TURBO", "BENCHMARK")]
        [string]$Level = "INFO",
        
        [Parameter(Mandatory = $false)]
        [string]$Prefix = "PERF"
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss.fff"
    $color = switch ($Level) {
        "ERROR"     { "Red" }
        "SUCCESS"   { "Green" }
        "WARNING"   { "Yellow" }
        "TURBO"     { "Magenta" }
        "BENCHMARK" { "Cyan" }
        default     { "White" }
    }
    
    Write-Host "[$timestamp] $Prefix [$Level]: $Message" -ForegroundColor $color
}

function Write-PerformanceHeader {
    <#
    .SYNOPSIS
        Display a formatted header for experiment sections
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        
        [Parameter(Mandatory = $false)]
        [string]$BorderChar = '='
    )
    
    $borderLength = 80
    $border = $BorderChar[0].ToString() * $borderLength
    Write-Host ""
    Write-Host $border -ForegroundColor Cyan
    Write-Host $Title.ToUpper().PadLeft(($borderLength + $Title.Length) / 2) -ForegroundColor Cyan
    Write-Host $border -ForegroundColor Cyan
    Write-Host ""
}

#endregion

#region Git Configuration Management

function Invoke-WithGitConfig {
    <#
    .SYNOPSIS
        Executes a script block with temporary Git configuration changes
    
    .DESCRIPTION
        Safely applies Git configuration changes, executes the provided script block,
        and ensures the original configuration is restored even if errors occur.
    
    .EXAMPLE
        $configs = @{
            "core.preloadindex" = "true"
            "core.fscache" = "true"
        }
        Invoke-WithGitConfig -Configurations $configs -ScriptBlock {
            # Your test code here
        } -ShowDetails
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Configurations,
        
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter(Mandatory = $false)]
        [switch]$Global,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDetails
    )
    
    $scope = if ($Global) { "--global" } else { "--local" }
    
    # Backup current configurations
    $backups = @{}
    foreach ($key in $Configurations.Keys) {
        try {
            $currentValue = git config $scope $key 2>$null
            if ($LASTEXITCODE -eq 0 -and $currentValue) {
                $backups[$key] = $currentValue
                if ($ShowDetails) {
                    Write-PerformanceLog "Backed up: $key = $currentValue" -Level "INFO"
                }
            }
        }
        catch {
            # Config doesn't exist, which is fine - silently continue
            Write-Verbose "Config key $key not found in current scope"
        }
    }
    
    try {
        # Apply new configurations
        foreach ($config in $Configurations.GetEnumerator()) {
            git config $scope $config.Key $config.Value 2>$null
            if ($ShowDetails) {
                Write-PerformanceLog "Applied: $($config.Key) = $($config.Value)" -Level "SUCCESS"
            }
        }
        
        # Execute the script block
        & $ScriptBlock
    }
    finally {
        # Restore original configurations
        foreach ($key in $Configurations.Keys) {
            if ($backups.ContainsKey($key)) {
                git config $scope $key $backups[$key] 2>$null
                if ($ShowDetails) {
                    Write-PerformanceLog "Restored: $key = $($backups[$key])" -Level "INFO"
                }
            }
            else {
                git config $scope --unset $key 2>$null
                if ($ShowDetails) {
                    Write-PerformanceLog "Unset: $key" -Level "INFO"
                }
            }
        }
    }
}

#endregion

#region Performance Measurement

function Measure-StandardGitOperations {
    <#
    .SYNOPSIS
        Measures standard Git operations (baseline performance)
    
    .DESCRIPTION
        Creates a consistent baseline measurement of standard Git operations
        including init, file creation, staging, and commit.
    
    .EXAMPLE
        $results = Measure-StandardGitOperations -NumFiles 100 -TestDirectory "C:\temp\test"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [int]$NumFiles,
        
        [Parameter(Mandatory = $true)]
        [string]$TestDirectory,
        
        [Parameter(Mandatory = $false)]
        [switch]$Verbose
    )
    
    $results = @{
        Init = 0
        FileCreation = 0
        Staging = 0
        Commit = 0
        Total = 0
    }
    
    $overallTimer = [System.Diagnostics.Stopwatch]::StartNew()
    $timer = [System.Diagnostics.Stopwatch]::new()
    
    try {
        # Measure: Git Init
        $timer.Start()
        git init --quiet 2>$null
        $timer.Stop()
        $results.Init = $timer.ElapsedMilliseconds
        if ($Verbose) {
            Write-PerformanceLog "Init: $($results.Init)ms" -Level "BENCHMARK"
        }
        
        # Measure: File Creation
        $timer.Restart()
        1..$NumFiles | ForEach-Object {
            $content = "Standard file $_ content: $(Get-Random)"
            [System.IO.File]::WriteAllText("$TestDirectory\file$_.txt", $content)
        }
        $timer.Stop()
        $results.FileCreation = $timer.ElapsedMilliseconds
        if ($Verbose) {
            Write-PerformanceLog "File Creation: $($results.FileCreation)ms" -Level "BENCHMARK"
        }
        
        # Measure: Staging
        $timer.Restart()
        git add . 2>$null
        $timer.Stop()
        $results.Staging = $timer.ElapsedMilliseconds
        if ($Verbose) {
            Write-PerformanceLog "Staging: $($results.Staging)ms" -Level "BENCHMARK"
        }
        
        # Measure: Commit
        $timer.Restart()
        git commit -m "Standard commit" --quiet 2>$null
        $timer.Stop()
        $results.Commit = $timer.ElapsedMilliseconds
        if ($Verbose) {
            Write-PerformanceLog "Commit: $($results.Commit)ms" -Level "BENCHMARK"
        }
        
        $overallTimer.Stop()
        $results.Total = $overallTimer.ElapsedMilliseconds
        
        return $results
    }
    catch {
        Write-PerformanceLog "Error in standard operations: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Get-MemoryUsage {
    <#
    .SYNOPSIS
        Gets current memory usage statistics
    
    .DESCRIPTION
        Returns memory usage information for the current process and system
    #>
    param(
        [Parameter(Mandatory = $false)]
        [switch]$IncludeSystem
    )
    
    $process = Get-Process -Id $PID
    $memoryInfo = @{
        WorkingSet = [math]::Round($process.WorkingSet64 / 1MB, 2)
        PrivateMemory = [math]::Round($process.PrivateMemorySize64 / 1MB, 2)
        VirtualMemory = [math]::Round($process.VirtualMemorySize64 / 1MB, 2)
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    }
    
    if ($IncludeSystem) {
        $computerInfo = Get-CimInstance -ClassName Win32_OperatingSystem
        $memoryInfo.SystemTotalMemory = [math]::Round($computerInfo.TotalVisibleMemorySize / 1KB, 2)
        $memoryInfo.SystemFreeMemory = [math]::Round($computerInfo.FreePhysicalMemory / 1KB, 2)
        $memoryInfo.SystemUsedPercent = [math]::Round((($computerInfo.TotalVisibleMemorySize - $computerInfo.FreePhysicalMemory) / $computerInfo.TotalVisibleMemorySize) * 100, 2)
    }
    
    return $memoryInfo
}

function Measure-OperationWithMemory {
    <#
    .SYNOPSIS
        Measures both execution time and memory usage of an operation
    
    .EXAMPLE
        $result = Measure-OperationWithMemory -ScriptBlock {
            git add .
        } -OperationName "Staging" -ShowDetails
    #>
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter(Mandatory = $true)]
        [string]$OperationName,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDetails
    )
    
    $memoryBefore = Get-MemoryUsage
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        & $ScriptBlock
        $success = $true
    }
    catch {
        $success = $false
        $errorMessage = $_.Exception.Message
    }
    finally {
        $timer.Stop()
        $memoryAfter = Get-MemoryUsage
    }
    
    $result = @{
        OperationName = $OperationName
        Success = $success
        ElapsedMilliseconds = $timer.ElapsedMilliseconds
        MemoryBefore = $memoryBefore.WorkingSet
        MemoryAfter = $memoryAfter.WorkingSet
        MemoryDelta = [math]::Round($memoryAfter.WorkingSet - $memoryBefore.WorkingSet, 2)
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    }
    
    if (-not $success) {
        $result.Error = $errorMessage
    }
    
    if ($ShowDetails) {
        $status = if ($success) { "SUCCESS" } else { "ERROR" }
        Write-PerformanceLog "$OperationName completed in $($result.ElapsedMilliseconds)ms (Memory: $($result.MemoryDelta)MB)" -Level $status
    }
    
    return $result
}

#endregion

#region Result Formatting and Analysis

function Format-PerformanceComparison {
    <#
    .SYNOPSIS
        Formats and displays performance comparison between standard and optimized operations
    
    .DESCRIPTION
        Calculates improvement percentages, speedup factors, and time saved.
        Handles edge cases like zero values gracefully.
    
    .EXAMPLE
        Format-PerformanceComparison -StandardTime 1000 -OptimizedTime 300 -OperationName "Staging"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [double]$StandardTime,
        
        [Parameter(Mandatory = $true)]
        [double]$OptimizedTime,
        
        [Parameter(Mandatory = $true)]
        [string]$OperationName,
        
        [Parameter(Mandatory = $false)]
        [switch]$Detailed
    )
    
    $comparison = @{
        Operation = $OperationName
        StandardTime = $StandardTime
        OptimizedTime = $OptimizedTime
        Improvement = 0
        Speedup = 1.0
        TimeSaved = 0
        Status = "No Change"
    }
    
    # Handle edge cases
    if ($StandardTime -le 0 -and $OptimizedTime -le 0) {
        $comparison.Status = "Both operations too fast to measure accurately"
        return $comparison
    }
    
    if ($StandardTime -le 0) {
        $comparison.Status = "Standard operation too fast to measure"
        return $comparison
    }
    
    if ($OptimizedTime -le 0) {
        $comparison.Improvement = 100
        $comparison.Speedup = [double]::PositiveInfinity
        $comparison.TimeSaved = $StandardTime
        $comparison.Status = "Optimized operation completed instantly"
        return $comparison
    }
    
    # Calculate metrics
    $comparison.Improvement = [math]::Round((($StandardTime - $OptimizedTime) / $StandardTime) * 100, 2)
    $comparison.Speedup = [math]::Round($StandardTime / $OptimizedTime, 2)
    $comparison.TimeSaved = [math]::Round($StandardTime - $OptimizedTime, 2)
    
    # Determine status
    if ($comparison.Improvement -gt 50) {
        $comparison.Status = "Excellent"
    }
    elseif ($comparison.Improvement -gt 25) {
        $comparison.Status = "Good"
    }
    elseif ($comparison.Improvement -gt 0) {
        $comparison.Status = "Marginal"
    }
    elseif ($comparison.Improvement -eq 0) {
        $comparison.Status = "No Change"
    }
    else {
        $comparison.Status = "Regression"
    }
    
    # Display results
    if ($Detailed) {
        Write-Host ""
        Write-Host "  Operation: " -NoNewline
        Write-Host $OperationName -ForegroundColor Cyan
        Write-Host "  Standard:  " -NoNewline
        Write-Host "$($StandardTime)ms" -ForegroundColor Yellow
        Write-Host "  Optimized: " -NoNewline
        Write-Host "$($OptimizedTime)ms" -ForegroundColor Green
        Write-Host "  Improvement: " -NoNewline
        
        $improvementColor = if ($comparison.Improvement -gt 0) { "Green" } elseif ($comparison.Improvement -lt 0) { "Red" } else { "Yellow" }
        Write-Host "$($comparison.Improvement)%" -ForegroundColor $improvementColor
        
        Write-Host "  Speedup:   " -NoNewline
        Write-Host "$($comparison.Speedup)x" -ForegroundColor Magenta
        Write-Host "  Time Saved: " -NoNewline
        Write-Host "$($comparison.TimeSaved)ms" -ForegroundColor Green
        Write-Host "  Status:    " -NoNewline
        
        $statusColor = switch ($comparison.Status) {
            "Excellent" { "Green" }
            "Good" { "Cyan" }
            "Marginal" { "Yellow" }
            "Regression" { "Red" }
            default { "White" }
        }
        Write-Host $comparison.Status -ForegroundColor $statusColor
        Write-Host ""
    }
    
    return $comparison
}

function Export-PerformanceResults {
    <#
    .SYNOPSIS
        Exports performance results to JSON file
    
    .EXAMPLE
        Export-PerformanceResults -Results $results -OutputPath "results.json"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$Results,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $false)]
        [switch]$PrettyPrint
    )
    
    try {
        $jsonDepth = 10
        
        if ($PrettyPrint) {
            $json = $Results | ConvertTo-Json -Depth $jsonDepth
        }
        else {
            $json = $Results | ConvertTo-Json -Depth $jsonDepth -Compress
        }
        
        $json | Out-File -FilePath $OutputPath -Encoding utf8 -Force
        Write-PerformanceLog "Results exported to: $OutputPath" -Level "SUCCESS"
        
        return $true
    }
    catch {
        Write-PerformanceLog "Failed to export results: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Test-PerformanceRegression {
    <#
    .SYNOPSIS
        Checks if performance has regressed compared to baseline
    
    .EXAMPLE
        $hasRegression = Test-PerformanceRegression -BaselineFile "baseline.json" -CurrentResults $results -Threshold 10
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaselineFile,
        
        [Parameter(Mandatory = $true)]
        [object]$CurrentResults,
        
        [Parameter(Mandatory = $false)]
        [double]$Threshold = 5.0  # 5% regression threshold
    )
    
    if (-not (Test-Path $BaselineFile)) {
        Write-PerformanceLog "Baseline file not found: $BaselineFile" -Level "WARNING"
        return $false
    }
    
    try {
        $baseline = Get-Content $BaselineFile -Raw | ConvertFrom-Json
        $regressions = @()
        
        foreach ($operation in $CurrentResults.PSObject.Properties.Name) {
            if ($baseline.PSObject.Properties.Name -contains $operation) {
                $baselineValue = $baseline.$operation
                $currentValue = $CurrentResults.$operation
                
                if ($baselineValue -gt 0) {
                    $change = (($currentValue - $baselineValue) / $baselineValue) * 100
                    
                    if ($change -gt $Threshold) {
                        $regressions += @{
                            Operation = $operation
                            BaselineTime = $baselineValue
                            CurrentTime = $currentValue
                            PercentageSlower = [math]::Round($change, 2)
                        }
                    }
                }
            }
        }
        
        if ($regressions.Count -gt 0) {
            Write-PerformanceLog "Performance regressions detected:" -Level "WARNING"
            foreach ($regression in $regressions) {
                Write-PerformanceLog "  $($regression.Operation): $($regression.PercentageSlower)% slower" -Level "WARNING"
            }
            return $true
        }
        else {
            Write-PerformanceLog "No performance regressions detected" -Level "SUCCESS"
            return $false
        }
    }
    catch {
        Write-PerformanceLog "Error checking regression: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

#endregion

#region Test Environment Management

function New-PerformanceTestEnvironment {
    <#
    .SYNOPSIS
        Creates a clean test environment for performance measurements
    
    .EXAMPLE
        $testEnv = New-PerformanceTestEnvironment -BasePath "C:\temp" -TestName "staging-test"
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$BasePath = $env:TEMP,
        
        [Parameter(Mandatory = $true)]
        [string]$TestName,
        
        [Parameter(Mandatory = $false)]
        [switch]$CleanupExisting
    )
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $testDir = Join-Path $BasePath "gitzoom-$TestName-$timestamp"
    
    if ($CleanupExisting -and (Test-Path $testDir)) {
        if ($PSCmdlet.ShouldProcess($testDir, "Remove existing test directory")) {
            Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    if ($PSCmdlet.ShouldProcess($testDir, "Create test directory")) {
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
    }
    
    $environment = @{
        TestDirectory = $testDir
        TestName = $TestName
        Timestamp = $timestamp
        StartTime = Get-Date
        OriginalLocation = Get-Location
    }
    
    Set-Location $testDir
    Write-PerformanceLog "Test environment created: $testDir" -Level "SUCCESS"
    
    return $environment
}

function Remove-PerformanceTestEnvironment {
    <#
    .SYNOPSIS
        Cleans up test environment and restores original location
    
    .EXAMPLE
        Remove-PerformanceTestEnvironment -Environment $testEnv
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Environment,
        
        [Parameter(Mandatory = $false)]
        [switch]$KeepResults
    )
    
    try {
        Set-Location $Environment.OriginalLocation
        
        if (-not $KeepResults) {
            if (Test-Path $Environment.TestDirectory) {
                if ($PSCmdlet.ShouldProcess($Environment.TestDirectory, "Remove test environment")) {
                    Remove-Item -Path $Environment.TestDirectory -Recurse -Force -ErrorAction SilentlyContinue
                    Write-PerformanceLog "Test environment cleaned up" -Level "SUCCESS"
                }
            }
        }
        else {
            Write-PerformanceLog "Test results preserved at: $($Environment.TestDirectory)" -Level "INFO"
        }
    }
    catch {
        Write-PerformanceLog "Error cleaning up test environment: $($_.Exception.Message)" -Level "WARNING"
    }
}

#endregion

# Note: This file can be dot-sourced or imported as a module
# When dot-sourcing, all functions will be available in the calling scope

#endregion
