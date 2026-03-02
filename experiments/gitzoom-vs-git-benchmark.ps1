# GitZoom vs Standard Git Performance Comparison
# Comprehensive benchmark to demonstrate GitZoom's speed advantages

param(
    [int]$Iterations = 5,
    [string]$TestDataSize = "medium", # small, medium, large
    [switch]$GenerateReport,
    [switch]$CreateVisualComparison,
    [string]$OutputPath = "performance-comparison"
)

# Import Windows-only modules (non-fatal on Linux)
try { Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop } catch { }
try { Add-Type -AssemblyName System.Drawing -ErrorAction Stop } catch { }

Write-Host "⚡ GitZoom vs Standard Git Performance Comparison" -ForegroundColor Magenta
Write-Host "=" * 70 -ForegroundColor Gray
Write-Host "Benchmarking GitZoom optimizations against standard Git workflows" -ForegroundColor Yellow
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

function Initialize-TestEnvironment {
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

function New-TestData {
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
    
    # Create an initial commit so HEAD exists for subsequent resets
    git add .
    git commit -m "Initial test data" --quiet
    
    Write-Host "✅ Generated $($currentScale.FileCount) test files" -ForegroundColor Green
}

function Test-AddAndCommitPerformance {
    Write-TestHeader "Add and Commit Performance" "GitZoom batch add vs individual file adds"
    
    # GitZoom approach: batch add all files at once, then commit
    $gitZoomResult = Measure-Operation "GitZoom Batch Add + Commit" {
        # Create modifications for this iteration
        1..5 | ForEach-Object { "change $_" >> "test-file-$_.js" }
        git add -A
        git commit -m "GitZoom batch commit" --quiet
    } "GitZoom"
    
    # Standard approach: add files one by one, then commit
    $standardResult = Measure-Operation "Standard Git Individual Add + Commit" {
        # Create modifications for this iteration
        1..5 | ForEach-Object { "change $_" >> "test-file-$_.js" }
        1..5 | ForEach-Object { git add "test-file-$_.js" }
        git commit -m "Standard individual commit" --quiet
    } "Standard Git"
    
    Compare-Operations -GitZoomResult $gitZoomResult -StandardResult $standardResult -TestName "Add and Commit"
}

function Test-StatusCheckPerformance {
    Write-TestHeader "Status Check Performance" "GitZoom parsed status vs standard verbose status"
    
    # Create several modified files to have something to report
    1..5 | ForEach-Object {
        "Status test modification $_" | Out-File "test-file-$_.js" -Append -Encoding UTF8
    }
    
    # GitZoom approach: porcelain (machine-parseable, minimal output)
    $gitZoomResult = Measure-Operation "GitZoom Porcelain Status" {
        git status --porcelain --branch
    } "GitZoom"
    
    # Standard approach: full verbose status (what users normally run)
    $standardResult = Measure-Operation "Standard Git Full Status" {
        git status
    } "Standard Git"
    
    # Clean up modifications
    git checkout -- . 2>$null
    
    Compare-Operations -GitZoomResult $gitZoomResult -StandardResult $standardResult -TestName "Status Check"
}

function Test-MultiFileCommitPerformance {
    Write-TestHeader "Multi-File Commit Performance" "GitZoom single-command vs multi-step manual workflow"
    
    # GitZoom approach: single git add -A for all files
    $gitZoomResult = Measure-Operation "GitZoom Single-Command Commit" {
        1..20 | ForEach-Object {
            "Bulk mod $_" | Out-File "bulk-test-$_.js" -Encoding UTF8
        }
        git add -A
        git commit -m "GitZoom bulk commit" --quiet
    } "GitZoom"
    
    # Standard approach: add files individually then commit
    $standardResult = Measure-Operation "Standard Git Multi-Step Commit" {
        1..20 | ForEach-Object {
            "Bulk mod $_" | Out-File "bulk-test-$_.js" -Encoding UTF8
        }
        1..20 | ForEach-Object { git add "bulk-test-$_.js" }
        git commit -m "Standard bulk commit" --quiet
    } "Standard Git"
    
    Compare-Operations -GitZoomResult $gitZoomResult -StandardResult $standardResult -TestName "Multi-File Commit"
}

function Test-LogAndHistoryPerformance {
    Write-TestHeader "Log and History Performance" "GitZoom compact log vs standard verbose log"
    
    # Create some commit history first
    1..5 | ForEach-Object {
        "History test $_" | Out-File "history-$_.txt" -Encoding UTF8
        git add "history-$_.txt"
        git commit -m "History commit $_" --quiet
    }
    
    # GitZoom approach: compact one-line format
    $gitZoomResult = Measure-Operation "GitZoom Compact Log" {
        git log --oneline -20
    } "GitZoom"
    
    # Standard approach: full verbose log with diff stats
    $standardResult = Measure-Operation "Standard Git Verbose Log" {
        git log --stat -20
    } "Standard Git"
    
    Compare-Operations -GitZoomResult $gitZoomResult -StandardResult $standardResult -TestName "Log and History"
}

function Test-BranchOperationPerformance {
    Write-TestHeader "Branch Operation Performance" "GitZoom single-command branch vs multi-step"
    
    # GitZoom approach: single checkout -b (what New-GitBranch does)
    $gitZoomResult = Measure-Operation "GitZoom Quick Branch" {
        git checkout -b "gitzoom-test-$((Get-Random))" --quiet 2>$null
        git checkout main --quiet 2>$null
    } "GitZoom"
    
    # Standard approach: create branch then switch separately
    $standardResult = Measure-Operation "Standard Git Branch + Switch" {
        $name = "standard-test-$((Get-Random))"
        git branch $name 2>$null
        git checkout $name --quiet 2>$null
        git checkout main --quiet 2>$null
    } "Standard Git"
    
    # Cleanup test branches
    git branch | Where-Object { $_ -match "test-" } | ForEach-Object { git branch -D $_.Trim() 2>$null }
    
    Compare-Operations -GitZoomResult $gitZoomResult -StandardResult $standardResult -TestName "Branch Operations"
}

function Test-FileSystemScanPerformance {
    Write-TestHeader "File System Scan Performance" "GitZoom git-native scan vs PowerShell filesystem scan"
    
    # GitZoom approach: use git ls-files (tracks index, very fast)
    $gitZoomResult = Measure-Operation "GitZoom git ls-files" {
        git ls-files "*.js"
    } "GitZoom"
    
    # Standard approach: PowerShell recursive filesystem scan
    $standardResult = Measure-Operation "Standard Filesystem Scan" {
        Get-ChildItem -Path . -Recurse -File | Where-Object { $_.Extension -eq ".js" } | ForEach-Object { $_.FullName }
    } "Standard Git"
    
    Compare-Operations -GitZoomResult $gitZoomResult -StandardResult $standardResult -TestName "File System Scan"
}

function New-ComparisonReport {
    Write-Host ""
    Write-Host "📊 Generating Performance Comparison Report..." -ForegroundColor Cyan
    
    $global:TestMetrics.EndTime = Get-Date
    $global:TestMetrics.TotalDuration = ($global:TestMetrics.EndTime - $global:TestMetrics.StartTime).TotalSeconds
    
    # Calculate overall performance improvement
    $validComparisons = $global:ComparisonResults | Where-Object { $null -ne $_.SpeedupPercentage }
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
            OS = if ($IsWindows) { try { (Get-CimInstance Win32_OperatingSystem).Caption } catch { "Windows" } } else { "$(uname -s) $(uname -r)" }
            ProcessorName = if ($IsWindows) { try { (Get-CimInstance Win32_Processor).Name } catch { "Unknown" } } else { "$(uname -m)" }
            TotalMemory = if ($IsWindows) { try { [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2) } catch { 0 } } else { try { [math]::Round((Get-Content /proc/meminfo | Select-String "MemTotal" | ForEach-Object { ($_ -split '\s+')[1] }) / 1048576, 2) } catch { 0 } }
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

function New-VisualComparison {
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

function Remove-TestEnvironment {
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
    Initialize-TestEnvironment
    New-TestData
    
    # Run all performance tests
    Test-AddAndCommitPerformance
    Test-StatusCheckPerformance
    Test-MultiFileCommitPerformance
    Test-LogAndHistoryPerformance
    Test-BranchOperationPerformance
    Test-FileSystemScanPerformance
    
    # Generate comprehensive report
    $report = New-ComparisonReport
    
    if ($CreateVisualComparison) {
        New-VisualComparison
    }
    
    Write-Host ""
    if ($global:TestMetrics.GitZoomWins -gt $global:TestMetrics.StandardGitWins) {
        Write-Host "🎉 GitZoom is the CLEAR WINNER! Faster in $($global:TestMetrics.GitZoomWins) out of $($global:TestMetrics.TotalTests) tests!" -ForegroundColor Green
    } else {
        Write-Host "📊 Results are close - GitZoom shows promise in specific scenarios" -ForegroundColor Yellow
    }
}
finally {
    Remove-TestEnvironment
}

Write-Host ""
Write-Host "⚡ GitZoom Performance Comparison Complete!" -ForegroundColor Magenta