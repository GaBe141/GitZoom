# GitZoom Continuous Testing Framework
# Windows-focused continuous integration and performance monitoring

param(
    [string]$Mode = "watch", # watch, single, benchmark, regression
    [int]$IntervalSeconds = 300, # 5 minutes default for watch mode
    [switch]$EnableNotifications,
    [string]$BaselineFile = "",
    [int]$RegressionThreshold = 20 # Percentage threshold for regression detection
)

# Import Windows notification support
Add-Type -AssemblyName System.Windows.Forms

Write-Host "🔄 GitZoom Continuous Testing Framework" -ForegroundColor Magenta
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host "Mode: $Mode | Monitoring Windows performance continuously" -ForegroundColor Yellow
Write-Host ""

# Global state
$global:TestHistory = @()
$global:BaselineMetrics = $null
$global:IsRunning = $true

# Performance baseline structure
function Initialize-PerformanceBaseline {
    param([string]$BaselineFile)
    
    if ($BaselineFile -and (Test-Path $BaselineFile)) {
        Write-Host "📊 Loading baseline from: $BaselineFile" -ForegroundColor Cyan
        $baseline = Get-Content $BaselineFile | ConvertFrom-Json
        $global:BaselineMetrics = $baseline
        Write-Host "✅ Baseline loaded with $($baseline.Operations.Count) operations" -ForegroundColor Green
    } else {
        Write-Host "📊 Creating new performance baseline..." -ForegroundColor Cyan
        $global:BaselineMetrics = @{
            CreatedAt = Get-Date
            SystemInfo = Get-SystemInfo
            Operations = @{}
        }
    }
}

function Get-SystemInfo {
    return @{
        OS = (Get-CimInstance Win32_OperatingSystem).Caption
        Version = (Get-CimInstance Win32_OperatingSystem).Version
        TotalMemory = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
        ProcessorCount = (Get-CimInstance Win32_ComputerSystem).NumberOfProcessors
        ProcessorName = (Get-CimInstance Win32_Processor).Name
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    }
}

function Send-WindowsNotification {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Type = "Info" # Info, Warning, Error
    )
    
    if (-not $EnableNotifications) { return }
    
    try {
        $balloon = New-Object System.Windows.Forms.NotifyIcon
        $balloon.Icon = [System.Drawing.SystemIcons]::Information
        $balloon.BalloonTipIcon = $Type
        $balloon.BalloonTipText = $Message
        $balloon.BalloonTipTitle = $Title
        $balloon.Visible = $true
        $balloon.ShowBalloonTip(5000)
        
        # Clean up after 5 seconds
        Start-Sleep -Seconds 5
        $balloon.Dispose()
    }
    catch {
        Write-Host "⚠️ Could not send notification: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Measure-GitZoomOperation {
    param(
        [string]$OperationName,
        [scriptblock]$Operation
    )
    
    # Collect pre-operation metrics
    $beforeMemory = [System.GC]::GetTotalMemory($false)
    $beforeCpu = (Get-Process -Id $PID).TotalProcessorTime
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        $result = & $Operation
        $stopwatch.Stop()
        
        # Collect post-operation metrics
        $afterMemory = [System.GC]::GetTotalMemory($false)
        $afterCpu = (Get-Process -Id $PID).TotalProcessorTime
        
        $metrics = @{
            Operation = $OperationName
            Duration = $stopwatch.ElapsedMilliseconds
            Success = $true
            MemoryUsed = $afterMemory - $beforeMemory
            CpuTime = ($afterCpu - $beforeCpu).TotalMilliseconds
            Timestamp = Get-Date
            Result = $result
        }
        
        return $metrics
    }
    catch {
        $stopwatch.Stop()
        
        $metrics = @{
            Operation = $OperationName
            Duration = $stopwatch.ElapsedMilliseconds
            Success = $false
            Error = $_.Exception.Message
            MemoryUsed = 0
            CpuTime = 0
            Timestamp = Get-Date
        }
        
        return $metrics
    }
}

function Run-CorePerformanceTests {
    Write-Host "🧪 Running core performance tests..." -ForegroundColor Cyan
    
    $testResults = @()
    
    # Test 1: File system operations
    $testResults += Measure-GitZoomOperation "File System Scan" {
        Get-ChildItem -Path . -Recurse -File | Measure-Object
    }
    
    # Test 2: Git status operation
    $testResults += Measure-GitZoomOperation "Git Status" {
        git status --porcelain 2>$null
    }
    
    # Test 3: Git log operation
    $testResults += Measure-GitZoomOperation "Git Log" {
        git log --oneline -10 2>$null
    }
    
    # Test 4: Memory allocation test
    $testResults += Measure-GitZoomOperation "Memory Allocation Test" {
        $largeArray = New-Object 'System.Collections.Generic.List[string]'
        1..1000 | ForEach-Object { $largeArray.Add("Test item $_") }
        return $largeArray.Count
    }
    
    # Test 5: PowerShell pipeline test
    $testResults += Measure-GitZoomOperation "PowerShell Pipeline" {
        1..1000 | Where-Object { $_ -gt 500 } | ForEach-Object { $_ * 2 } | Measure-Object -Sum
    }
    
    # Test 6: File I/O test
    $testResults += Measure-GitZoomOperation "File I/O Operations" {
        $tempFile = [System.IO.Path]::GetTempFileName()
        try {
            "Test content $(Get-Date)" | Out-File $tempFile -Encoding UTF8
            $content = Get-Content $tempFile
            return $content.Length
        }
        finally {
            if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
        }
    }
    
    return $testResults
}

function Analyze-PerformanceRegression {
    param([array]$CurrentResults)
    
    if (-not $global:BaselineMetrics -or -not $global:BaselineMetrics.Operations) {
        Write-Host "⚠️ No baseline metrics available for regression analysis" -ForegroundColor Yellow
        return
    }
    
    $regressions = @()
    
    foreach ($result in $CurrentResults) {
        $baseline = $global:BaselineMetrics.Operations[$result.Operation]
        
        if ($baseline -and $result.Success) {
            $percentageChange = [math]::Round((($result.Duration - $baseline.Duration) / $baseline.Duration) * 100, 2)
            
            if ($percentageChange -gt $RegressionThreshold) {
                $regressions += @{
                    Operation = $result.Operation
                    BaselineDuration = $baseline.Duration
                    CurrentDuration = $result.Duration
                    PercentageIncrease = $percentageChange
                }
                
                Write-Host "🔺 REGRESSION DETECTED: $($result.Operation)" -ForegroundColor Red
                Write-Host "   Baseline: $($baseline.Duration)ms → Current: $($result.Duration)ms ($percentageChange% increase)" -ForegroundColor Yellow
            }
            elseif ($percentageChange -lt -10) {
                Write-Host "🔽 IMPROVEMENT: $($result.Operation)" -ForegroundColor Green
                Write-Host "   Baseline: $($baseline.Duration)ms → Current: $($result.Duration)ms ($([math]::Abs($percentageChange))% decrease)" -ForegroundColor DarkGreen
            }
        }
    }
    
    if ($regressions.Count -gt 0) {
        $message = "Performance regression detected in $($regressions.Count) operation(s)"
        Send-WindowsNotification -Title "GitZoom Performance Alert" -Message $message -Type "Warning"
    }
    
    return $regressions
}

function Update-Baseline {
    param([array]$TestResults)
    
    if (-not $global:BaselineMetrics.Operations) {
        $global:BaselineMetrics.Operations = @{}
    }
    
    foreach ($result in $TestResults) {
        if ($result.Success) {
            $global:BaselineMetrics.Operations[$result.Operation] = @{
                Duration = $result.Duration
                MemoryUsed = $result.MemoryUsed
                CpuTime = $result.CpuTime
                LastUpdated = Get-Date
            }
        }
    }
    
    Write-Host "📊 Baseline updated with $($TestResults.Count) operations" -ForegroundColor Green
}

function Save-TestResults {
    param([array]$TestResults, [array]$Regressions = @())
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $resultsFile = "test-results/continuous-test-$timestamp.json"
    
    $report = @{
        Timestamp = Get-Date
        Mode = $Mode
        SystemInfo = Get-SystemInfo
        TestResults = $TestResults
        Regressions = $Regressions
        Summary = @{
            TotalTests = $TestResults.Count
            PassedTests = ($TestResults | Where-Object { $_.Success }).Count
            FailedTests = ($TestResults | Where-Object { -not $_.Success }).Count
            AverageDuration = [math]::Round(($TestResults | Where-Object { $_.Success } | Measure-Object -Property Duration -Average).Average, 2)
            TotalMemoryUsed = ($TestResults | Measure-Object -Property MemoryUsed -Sum).Sum
        }
    }
    
    # Ensure results directory exists
    if (!(Test-Path "test-results")) {
        New-Item -ItemType Directory -Path "test-results" -Force | Out-Null
    }
    
    $report | ConvertTo-Json -Depth 10 | Out-File $resultsFile -Encoding UTF8
    
    # Also update the global test history
    $global:TestHistory += $report
    
    # Keep only last 100 test runs in memory
    if ($global:TestHistory.Count -gt 100) {
        $global:TestHistory = $global:TestHistory[-100..-1]
    }
    
    Write-Host "💾 Test results saved: $resultsFile" -ForegroundColor Blue
}

function Show-RealTimeMetrics {
    param([array]$TestResults)
    
    Clear-Host
    Write-Host "🔄 GitZoom Continuous Testing - Real-Time Metrics" -ForegroundColor Magenta
    Write-Host "=" * 60 -ForegroundColor Gray
    Write-Host "Last Update: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
    Write-Host ""
    
    # Display current test results
    Write-Host "📊 Current Test Results:" -ForegroundColor Cyan
    foreach ($result in $TestResults) {
        $status = if ($result.Success) { "✅" } else { "❌" }
        $duration = if ($result.Success) { "$($result.Duration)ms" } else { "FAILED" }
        Write-Host "  $status $($result.Operation.PadRight(25)) $duration" -ForegroundColor White
    }
    
    Write-Host ""
    
    # Display historical trend if available
    if ($global:TestHistory.Count -gt 1) {
        Write-Host "📈 Historical Trend (Last 5 runs):" -ForegroundColor Cyan
        $recent = $global:TestHistory | Select-Object -Last 5
        
        foreach ($run in $recent) {
            $timestamp = $run.Timestamp.ToString("HH:mm:ss")
            $avgDuration = $run.Summary.AverageDuration
            Write-Host "  $timestamp - Avg: ${avgDuration}ms, Tests: $($run.Summary.TotalTests)" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "Press Ctrl+C to stop monitoring..." -ForegroundColor Yellow
}

function Start-WatchMode {
    Write-Host "👀 Starting watch mode (interval: $IntervalSeconds seconds)" -ForegroundColor Green
    Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Yellow
    Write-Host ""
    
    # Set up Ctrl+C handler
    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
        $global:IsRunning = $false
    } | Out-Null
    
    while ($global:IsRunning) {
        try {
            $testResults = Run-CorePerformanceTests
            $regressions = Analyze-PerformanceRegression -CurrentResults $testResults
            
            Save-TestResults -TestResults $testResults -Regressions $regressions
            Show-RealTimeMetrics -TestResults $testResults
            
            if ($regressions.Count -eq 0) {
                Write-Host "✅ No performance regressions detected" -ForegroundColor Green
            }
            
            # Wait for next interval
            Start-Sleep -Seconds $IntervalSeconds
        }
        catch {
            Write-Host "❌ Error in watch mode: $($_.Exception.Message)" -ForegroundColor Red
            Start-Sleep -Seconds 30 # Shorter wait on error
        }
    }
}

function Start-BenchmarkMode {
    Write-Host "🏁 Starting benchmark mode..." -ForegroundColor Green
    
    $iterations = 10
    $allResults = @()
    
    for ($i = 1; $i -le $iterations; $i++) {
        Write-Host "Benchmark iteration $i/$iterations" -ForegroundColor Cyan
        $testResults = Run-CorePerformanceTests
        $allResults += $testResults
        
        Start-Sleep -Seconds 2 # Brief pause between iterations
    }
    
    # Calculate benchmark statistics
    $operations = $allResults | Group-Object Operation
    
    Write-Host ""
    Write-Host "🏆 Benchmark Results:" -ForegroundColor Magenta
    
    foreach ($op in $operations) {
        $durations = $op.Group | Where-Object { $_.Success } | ForEach-Object { $_.Duration }
        
        if ($durations.Count -gt 0) {
            $avg = [math]::Round(($durations | Measure-Object -Average).Average, 2)
            $min = ($durations | Measure-Object -Minimum).Minimum
            $max = ($durations | Measure-Object -Maximum).Maximum
            $stddev = [math]::Round([math]::Sqrt(($durations | ForEach-Object { [math]::Pow($_ - $avg, 2) } | Measure-Object -Average).Average), 2)
            
            Write-Host "  $($op.Name):" -ForegroundColor White
            Write-Host "    Avg: ${avg}ms | Min: ${min}ms | Max: ${max}ms | StdDev: ${stddev}ms" -ForegroundColor Gray
        }
    }
    
    # Update baseline with benchmark results
    Update-Baseline -TestResults ($allResults | Where-Object { $_.Success })
    
    # Save benchmark results
    Save-TestResults -TestResults $allResults
}

# Main execution
Write-Host "Initializing continuous testing framework..." -ForegroundColor Yellow

Initialize-PerformanceBaseline -BaselineFile $BaselineFile

switch ($Mode.ToLower()) {
    "watch" {
        Start-WatchMode
    }
    "single" {
        Write-Host "🎯 Running single test cycle..." -ForegroundColor Green
        $testResults = Run-CorePerformanceTests
        $regressions = Analyze-PerformanceRegression -CurrentResults $testResults
        Save-TestResults -TestResults $testResults -Regressions $regressions
        Show-RealTimeMetrics -TestResults $testResults
    }
    "benchmark" {
        Start-BenchmarkMode
    }
    "regression" {
        Write-Host "🔍 Running regression test..." -ForegroundColor Green
        $testResults = Run-CorePerformanceTests
        $regressions = Analyze-PerformanceRegression -CurrentResults $testResults
        
        if ($regressions.Count -gt 0) {
            Write-Host "❌ Regression test FAILED - $($regressions.Count) regression(s) detected" -ForegroundColor Red
            exit 1
        } else {
            Write-Host "✅ Regression test PASSED - No performance degradation" -ForegroundColor Green
            exit 0
        }
    }
    default {
        Write-Host "Unknown mode: $Mode" -ForegroundColor Red
        Write-Host "Available modes: watch, single, benchmark, regression" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""
Write-Host "🎉 Continuous testing completed!" -ForegroundColor Magenta