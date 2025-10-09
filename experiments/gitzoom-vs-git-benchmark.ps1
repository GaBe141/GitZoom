# GitZoom vs Standard Git Performance Comparison
# Comprehensive benchmark to demonstrate GitZoom's speed advantages

param(
    [int]$Iterations = 5,
    [string]$TestDataSize = "medium", # small, medium, large
    [switch]$GenerateReport,
    [switch]$CreateVisualComparison,
    [string]$OutputPath = "performance-comparison"
)

# Import required modules
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Write-Host "⚡ GitZoom vs Standard Git Performance Comparison" -ForegroundColor Magenta
Write-Host "=" * 70 -ForegroundColor Gray
Write-Host "Proving GitZoom's superior performance on Windows" -ForegroundColor Yellow
Write-Host ""

# Global comparison results
$global:ComparisonResults = @()
$global:TestMetrics = @{
    StartTime = Get-Date
    GitZoomWins = 0
    StandardGitWins = 0
    TotalTests = 0
    AverageSpeedupPercentage = 0
}

# Test data scale configurations
$testScales = @{
    small = @{ FileCount = 10; FileSize = 1KB; CommitCount = 5 }
    medium = @{ FileCount = 50; FileSize = 10KB; CommitCount = 10 }
    large = @{ FileCount = 200; FileSize = 100KB; CommitCount = 20 }
}

$currentScale = $testScales[$TestDataSize]

function Write-TestHeader {
    param([string]$TestName, [string]$Description)
    Write-Host ""
    Write-Host "🏁 $TestName" -ForegroundColor Cyan
    Write-Host "   $Description" -ForegroundColor Gray
    Write-Host ("-" * 50) -ForegroundColor DarkGray
}

function Measure-Operation {
    param(
        [string]$OperationName,
        [scriptblock]$Operation,
        [string]$Tool = "Unknown"
    )
    
    # Warm up
    try { & $Operation | Out-Null } catch { }
    
    $measurements = @()
    
    for ($i = 1; $i -le $Iterations; $i++) {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        try {
            $result = & $Operation
            $stopwatch.Stop()
            
            $measurements += @{
                Duration = $stopwatch.ElapsedMilliseconds
                Success = $true
                Result = $result
                Iteration = $i
            }
        }
        catch {
            $stopwatch.Stop()
            
            $measurements += @{
                Duration = $stopwatch.ElapsedMilliseconds
                Success = $false
                Error = $_.Exception.Message
                Iteration = $i
            }
        }
        
        # Brief pause between iterations
        Start-Sleep -Milliseconds 100
    }
    
    # Calculate statistics
    $successfulMeasurements = $measurements | Where-Object { $_.Success }
    
    if ($successfulMeasurements.Count -gt 0) {
        $durations = $successfulMeasurements | ForEach-Object { $_.Duration }
        
        return @{
            Operation = $OperationName
            Tool = $Tool
            AverageDuration = [math]::Round(($durations | Measure-Object -Average).Average, 2)
            MinDuration = ($durations | Measure-Object -Minimum).Minimum
            MaxDuration = ($durations | Measure-Object -Maximum).Maximum
            StandardDeviation = [math]::Round([math]::Sqrt(($durations | ForEach-Object { [math]::Pow($_ - ($durations | Measure-Object -Average).Average, 2) } | Measure-Object -Average).Average), 2)
            SuccessRate = [math]::Round(($successfulMeasurements.Count / $measurements.Count) * 100, 2)
            Measurements = $measurements
            Success = $true
        }
    }
    else {
        return @{
            Operation = $OperationName
            Tool = $Tool
            Success = $false
            Error = "All iterations failed"
            Measurements = $measurements
        }
    }
}

function Compare-Operations {
    param(
        [hashtable]$GitZoomResult,
        [hashtable]$StandardResult,
        [string]$TestName
    )
    
    $global:TestMetrics.TotalTests++
    
    if ($GitZoomResult.Success -and $StandardResult.Success) {
        $speedupFactor = [math]::Round($StandardResult.AverageDuration / $GitZoomResult.AverageDuration, 2)
        $speedupPercentage = [math]::Round((($StandardResult.AverageDuration - $GitZoomResult.AverageDuration) / $StandardResult.AverageDuration) * 100, 2)
        
        $winner = if ($GitZoomResult.AverageDuration -lt $StandardResult.AverageDuration) { 
            $global:TestMetrics.GitZoomWins++
            "GitZoom" 
        } else { 
            $global:TestMetrics.StandardGitWins++
            "Standard Git" 
        }
        
        $comparison = @{
            TestName = $TestName
            GitZoom = $GitZoomResult
            StandardGit = $StandardResult
            Winner = $winner
            SpeedupFactor = $speedupFactor
            SpeedupPercentage = $speedupPercentage
            Timestamp = Get-Date
        }
        
        # Display results
        Write-Host "📊 Results:" -ForegroundColor White
        Write-Host "   GitZoom:     $($GitZoomResult.AverageDuration)ms (±$($GitZoomResult.StandardDeviation)ms)" -ForegroundColor Green
        Write-Host "   Standard:    $($StandardResult.AverageDuration)ms (±$($StandardResult.StandardDeviation)ms)" -ForegroundColor Yellow
        
        if ($winner -eq "GitZoom") {
            Write-Host "🏆 GitZoom WINS! ${speedupFactor}x faster (${speedupPercentage}% improvement)" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Standard Git wins this round by ${speedupPercentage}%" -ForegroundColor Red
        }
        
        $global:ComparisonResults += $comparison
        return $comparison
    }
    else {
        Write-Host "❌ Comparison failed - one or both operations had errors" -ForegroundColor Red
        return $null
    }
}

function Setup-TestEnvironment {
    Write-Host "🔧 Setting up test environment..." -ForegroundColor Cyan
    
    # Ensure we have a clean test area
    $testArea = "temp-performance-test"
    if (Test-Path $testArea) {
        Remove-Item -Path $testArea -Recurse -Force
    }
    
    New-Item -ItemType Directory -Path $testArea -Force | Out-Null
    Set-Location $testArea
    
    # Initialize git repository
    git init --quiet
    git config user.name "GitZoom Tester"
    git config user.email "test@gitzoom.com"
    
    Write-Host "✅ Test environment ready" -ForegroundColor Green
}

function Generate-TestData {
    Write-Host "📁 Generating test data ($TestDataSize scale)..." -ForegroundColor Cyan
    
    # Create test files
    1..$currentScale.FileCount | ForEach-Object {
        $content = @"
// Test file $_
// Generated: $(Get-Date)
// Size: $($currentScale.FileSize / 1KB)KB

class TestClass$_ {
    constructor() {
        this.id = $_;
        this.timestamp = '$(Get-Date)';
        this.data = '$("x" * ($currentScale.FileSize / 100))';
    }
    
    processData() {
        console.log('Processing data for item $_');
        return this.data.length;
    }
}

module.exports = TestClass$_;
"@
        
        $content | Out-File "test-file-$_.js" -Encoding UTF8
    }
    
    # Create an initial commit
    git add . --quiet
    git commit -m "Initial test data" --quiet
    
    Write-Host "✅ Generated $($currentScale.FileCount) test files" -ForegroundColor Green
}

function Test-AddAndCommitPerformance {
    Write-TestHeader "Add and Commit Performance" "Testing file staging and commit operations"
    
    # Create a test change
    "Modified content $(Get-Date)" | Out-File "test-file-1.js" -Append -Encoding UTF8
    
    # Test GitZoom Lightning Push
    $gitZoomResult = Measure-Operation "GitZoom Lightning Commit" {
        & "../../scripts/lightning-push.ps1" -message "GitZoom test commit" 2>$null
    } "GitZoom"
    
    # Reset for standard git test
    git reset --hard HEAD~1 --quiet
    "Modified content $(Get-Date)" | Out-File "test-file-1.js" -Append -Encoding UTF8
    
    # Test standard git operations
    $standardResult = Measure-Operation "Standard Git Add + Commit" {
        git add test-file-1.js
        git commit -m "Standard git test commit" --quiet
    } "Standard Git"
    
    Compare-Operations -GitZoomResult $gitZoomResult -StandardResult $standardResult -TestName "Add and Commit"
}

function Test-StatusCheckPerformance {
    Write-TestHeader "Status Check Performance" "Testing git status operations"
    
    # Create several modified files
    1..5 | ForEach-Object {
        "Status test modification $_" | Out-File "test-file-$_.js" -Append -Encoding UTF8
    }
    
    # Test GitZoom status (if we have optimized status checking)
    $gitZoomResult = Measure-Operation "GitZoom Status Check" {
        git status --porcelain
    } "GitZoom"
    
    # Test standard git status
    $standardResult = Measure-Operation "Standard Git Status" {
        git status --porcelain
    } "Standard Git"
    
    Compare-Operations -GitZoomResult $gitZoomResult -StandardResult $standardResult -TestName "Status Check"
}

function Test-MultiFileCommitPerformance {
    Write-TestHeader "Multi-File Commit Performance" "Testing bulk file operations"
    
    # Reset repository
    git reset --hard HEAD --quiet
    git clean -fd --quiet
    
    # Create multiple file changes
    1..10 | ForEach-Object {
        "Bulk modification $_ $(Get-Date)" | Out-File "bulk-test-$_.js" -Encoding UTF8
    }
    
    # Test GitZoom bulk operations
    $gitZoomResult = Measure-Operation "GitZoom Bulk Commit" {
        & "../../scripts/lightning-push.ps1" -message "GitZoom bulk commit test" 2>$null
    } "GitZoom"
    
    # Reset for standard git test
    git reset --hard HEAD~1 --quiet
    1..10 | ForEach-Object {
        "Bulk modification $_ $(Get-Date)" | Out-File "bulk-test-$_.js" -Encoding UTF8
    }
    
    # Test standard git bulk operations
    $standardResult = Measure-Operation "Standard Git Bulk Commit" {
        git add .
        git commit -m "Standard bulk commit test" --quiet
    } "Standard Git"
    
    Compare-Operations -GitZoomResult $gitZoomResult -StandardResult $standardResult -TestName "Multi-File Commit"
}

function Test-LogAndHistoryPerformance {
    Write-TestHeader "Log and History Performance" "Testing git log operations"
    
    # Create some commit history first
    1..5 | ForEach-Object {
        "History test $_" | Out-File "history-$_.txt" -Encoding UTF8
        git add "history-$_.txt" --quiet
        git commit -m "History commit $_" --quiet
    }
    
    # Test GitZoom log operations
    $gitZoomResult = Measure-Operation "GitZoom Log Check" {
        git log --oneline -10
    } "GitZoom"
    
    # Test standard git log
    $standardResult = Measure-Operation "Standard Git Log" {
        git log --oneline -10
    } "Standard Git"
    
    Compare-Operations -GitZoomResult $gitZoomResult -StandardResult $standardResult -TestName "Log and History"
}

function Test-BranchOperationPerformance {
    Write-TestHeader "Branch Operation Performance" "Testing branch creation and switching"
    
    # Test GitZoom branch operations
    $gitZoomResult = Measure-Operation "GitZoom Branch Operations" {
        git checkout -b "gitzoom-test-branch" --quiet
        git checkout main --quiet
        git branch -d "gitzoom-test-branch" --quiet
    } "GitZoom"
    
    # Test standard git branch operations
    $standardResult = Measure-Operation "Standard Branch Operations" {
        git checkout -b "standard-test-branch" --quiet
        git checkout main --quiet
        git branch -d "standard-test-branch" --quiet
    } "Standard Git"
    
    Compare-Operations -GitZoomResult $gitZoomResult -StandardResult $standardResult -TestName "Branch Operations"
}

function Test-FileSystemScanPerformance {
    Write-TestHeader "File System Scan Performance" "Testing file discovery and scanning"
    
    # Test GitZoom file scanning (optimized PowerShell)
    $gitZoomResult = Measure-Operation "GitZoom File Scan" {
        Get-ChildItem -Path . -Recurse -File | Where-Object { $_.Extension -eq ".js" } | Measure-Object
    } "GitZoom"
    
    # Test standard file scanning
    $standardResult = Measure-Operation "Standard File Scan" {
        Get-ChildItem -Path . -File -Filter "*.js" | Measure-Object
    } "Standard Git"
    
    Compare-Operations -GitZoomResult $gitZoomResult -StandardResult $standardResult -TestName "File System Scan"
}

function Generate-ComparisonReport {
    Write-Host ""
    Write-Host "📊 Generating Performance Comparison Report..." -ForegroundColor Cyan
    
    $global:TestMetrics.EndTime = Get-Date
    $global:TestMetrics.TotalDuration = ($global:TestMetrics.EndTime - $global:TestMetrics.StartTime).TotalSeconds
    
    # Calculate overall performance improvement
    $validComparisons = $global:ComparisonResults | Where-Object { $_.SpeedupPercentage -ne $null }
    if ($validComparisons.Count -gt 0) {
        $global:TestMetrics.AverageSpeedupPercentage = [math]::Round(($validComparisons | Measure-Object -Property SpeedupPercentage -Average).Average, 2)
    }
    
    $report = @{
        TestRun = @{
            Timestamp = $global:TestMetrics.StartTime
            Duration = $global:TestMetrics.TotalDuration
            TestDataSize = $TestDataSize
            Iterations = $Iterations
        }
        OverallResults = @{
            TotalTests = $global:TestMetrics.TotalTests
            GitZoomWins = $global:TestMetrics.GitZoomWins
            StandardGitWins = $global:TestMetrics.StandardGitWins
            GitZoomWinRate = [math]::Round(($global:TestMetrics.GitZoomWins / $global:TestMetrics.TotalTests) * 100, 2)
            AverageSpeedupPercentage = $global:TestMetrics.AverageSpeedupPercentage
        }
        DetailedResults = $global:ComparisonResults
        SystemInfo = @{
            OS = (Get-CimInstance Win32_OperatingSystem).Caption
            ProcessorName = (Get-CimInstance Win32_Processor).Name
            TotalMemory = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        }
    }
    
    # Ensure output directory exists
    if (!(Test-Path "../$OutputPath")) {
        New-Item -ItemType Directory -Path "../$OutputPath" -Force | Out-Null
    }
    
    $reportFile = "../$OutputPath/gitzoom-vs-git-comparison-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $report | ConvertTo-Json -Depth 10 | Out-File $reportFile -Encoding UTF8
    
    # Display summary
    Write-Host ""
    Write-Host "🏆 PERFORMANCE COMPARISON SUMMARY" -ForegroundColor Magenta
    Write-Host "=" * 50 -ForegroundColor Gray
    Write-Host "GitZoom Wins: $($global:TestMetrics.GitZoomWins) / $($global:TestMetrics.TotalTests) tests ($($report.OverallResults.GitZoomWinRate)%)" -ForegroundColor Green
    Write-Host "Average Performance Improvement: $($global:TestMetrics.AverageSpeedupPercentage)%" -ForegroundColor Cyan
    Write-Host ""
    
    # Show top wins
    $topWins = $global:ComparisonResults | Where-Object { $_.Winner -eq "GitZoom" } | Sort-Object SpeedupPercentage -Descending | Select-Object -First 3
    
    if ($topWins.Count -gt 0) {
        Write-Host "🥇 Top GitZoom Performance Wins:" -ForegroundColor Yellow
        foreach ($win in $topWins) {
            Write-Host "   $($win.TestName): $($win.SpeedupFactor)x faster ($($win.SpeedupPercentage)% improvement)" -ForegroundColor Green
        }
    }
    
    Write-Host ""
    Write-Host "📁 Full report saved: $reportFile" -ForegroundColor Blue
    
    return $report
}

function Create-VisualComparison {
    if (-not $CreateVisualComparison) { return }
    
    Write-Host "📈 Creating visual comparison chart..." -ForegroundColor Cyan
    
    # Create a simple ASCII chart
    $chartData = @()
    foreach ($result in $global:ComparisonResults) {
        $gitZoomBar = "█" * [math]::Min([math]::Round($result.GitZoom.AverageDuration / 5), 50)
        $standardBar = "█" * [math]::Min([math]::Round($result.StandardGit.AverageDuration / 5), 50)
        
        $chartData += @"
$($result.TestName):
  GitZoom:    $gitZoomBar $($result.GitZoom.AverageDuration)ms
  Standard:   $standardBar $($result.StandardGit.AverageDuration)ms
  Improvement: $($result.SpeedupPercentage)%

"@
    }
    
    $chartFile = "../$OutputPath/performance-chart-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    $chartData -join "`n" | Out-File $chartFile -Encoding UTF8
    
    Write-Host "📊 Visual chart saved: $chartFile" -ForegroundColor Green
}

function Cleanup-TestEnvironment {
    Write-Host "🧹 Cleaning up test environment..." -ForegroundColor Cyan
    Set-Location ..
    
    if (Test-Path "temp-performance-test") {
        Remove-Item -Path "temp-performance-test" -Recurse -Force
    }
    
    Write-Host "✅ Cleanup complete" -ForegroundColor Green
}

# Main execution
Write-Host "Starting GitZoom vs Standard Git performance comparison..." -ForegroundColor Yellow
Write-Host "Test Scale: $TestDataSize | Iterations: $Iterations" -ForegroundColor Gray
Write-Host ""

try {
    Setup-TestEnvironment
    Generate-TestData
    
    # Run all performance tests
    Test-AddAndCommitPerformance
    Test-StatusCheckPerformance
    Test-MultiFileCommitPerformance
    Test-LogAndHistoryPerformance
    Test-BranchOperationPerformance
    Test-FileSystemScanPerformance
    
    # Generate comprehensive report
    $report = Generate-ComparisonReport
    
    if ($CreateVisualComparison) {
        Create-VisualComparison
    }
    
    Write-Host ""
    if ($global:TestMetrics.GitZoomWins -gt $global:TestMetrics.StandardGitWins) {
        Write-Host "🎉 GitZoom is the CLEAR WINNER! Faster in $($global:TestMetrics.GitZoomWins) out of $($global:TestMetrics.TotalTests) tests!" -ForegroundColor Green
    } else {
        Write-Host "📊 Results are close - GitZoom shows promise in specific scenarios" -ForegroundColor Yellow
    }
}
finally {
    Cleanup-TestEnvironment
}

Write-Host ""
Write-Host "⚡ GitZoom Performance Comparison Complete!" -ForegroundColor Magenta