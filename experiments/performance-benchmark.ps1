# Performance Benchmarking Script for GitZoom
param(
    [string]$TestScenario = "all",
    [int]$Iterations = 5,
    [switch]$GenerateReport
)

# Import required modules
Add-Type -AssemblyName System.Windows.Forms

Write-Host "🧪 GitZoom Performance Benchmarker" -ForegroundColor Magenta
Write-Host "=" * 50 -ForegroundColor Gray

# Performance tracking
$results = @()

function Measure-GitOperation {
    param(
        [string]$OperationName,
        [scriptblock]$Operation,
        [string]$TestData = ""
    )
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        & $Operation
        $stopwatch.Stop()
        
        $result = [PSCustomObject]@{
            Operation = $OperationName
            Duration = $stopwatch.ElapsedMilliseconds
            Success = $true
            TestData = $TestData
            Timestamp = Get-Date
        }
        
        Write-Host "✅ $OperationName`: $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Green
    }
    catch {
        $stopwatch.Stop()
        
        $result = [PSCustomObject]@{
            Operation = $OperationName
            Duration = $stopwatch.ElapsedMilliseconds
            Success = $false
            Error = $_.Exception.Message
            TestData = $TestData
            Timestamp = Get-Date
        }
        
        Write-Host "❌ $OperationName`: Failed after $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Red
    }
    
    return $result
}

function Test-SmallFileOperations {
    Write-Host "🧪 Testing Small File Operations..." -ForegroundColor Cyan
    
    # Create test files
    1..10 | ForEach-Object {
        $content = "Test content for file $_`nLine 2`nLine 3"
        $content | Out-File "test-data/small-file-$_.txt" -Encoding UTF8
    }
    
    # Test staging
    $result1 = Measure-GitOperation "Stage Small Files" {
        git add test-data/small-file-*.txt
    } "10 files, ~100 bytes each"
    
    # Test commit
    $result2 = Measure-GitOperation "Commit Small Files" {
        git commit -m "test: add small test files"
    } "10 files committed"
    
    return @($result1, $result2)
}

function Test-LargeFileOperations {
    Write-Host "🧪 Testing Large File Operations..." -ForegroundColor Cyan
    
    # Create a larger test file (1MB)
    $largeContent = "A" * 1048576  # 1MB of 'A' characters
    $largeContent | Out-File "test-data/large-file.txt" -Encoding UTF8
    
    # Test staging large file
    $result1 = Measure-GitOperation "Stage Large File" {
        git add test-data/large-file.txt
    } "1MB file"
    
    # Test commit large file
    $result2 = Measure-GitOperation "Commit Large File" {
        git commit -m "test: add large test file"
    } "1MB file committed"
    
    return @($result1, $result2)
}

function Test-GitZoomLightningPush {
    Write-Host "🧪 Testing GitZoom Lightning Push..." -ForegroundColor Cyan
    
    # Create test change
    "Test change $(Get-Date)" | Out-File "test-data/lightning-test.txt" -Encoding UTF8
    
    # Test GitZoom lightning push
    $result = Measure-GitOperation "GitZoom Lightning Push" {
        & "$PSScriptRoot\..\scripts\lightning-push.ps1" -message "test: lightning push benchmark"
    } "Single file change"
    
    return $result
}

function Test-NetworkLatency {
    Write-Host "🧪 Testing Network Operations..." -ForegroundColor Cyan
    
    # Test fetch operation
    $result1 = Measure-GitOperation "Git Fetch" {
        git fetch origin
    } "Fetch from remote"
    
    # Test push operation (if there are changes)
    $result2 = Measure-GitOperation "Git Push" {
        git push origin main
    } "Push to remote"
    
    return @($result1, $result2)
}

function Test-VSCodeIntegration {
    Write-Host "🧪 Testing VS Code Integration..." -ForegroundColor Cyan
    
    # Simulate VS Code file save + Git operations
    $result1 = Measure-GitOperation "File Save Simulation" {
        "// Updated at $(Get-Date)" | Out-File "test-data/vscode-test.js" -Encoding UTF8
    } "VS Code file save"
    
    # Test status check (common VS Code operation)
    $result2 = Measure-GitOperation "Git Status Check" {
        git status --porcelain
    } "Status for VS Code git panel"
    
    return @($result1, $result2)
}

# Main execution
Write-Host "🚀 Starting performance tests..." -ForegroundColor Yellow

# Ensure test-data directory exists
if (!(Test-Path "test-data")) {
    New-Item -ItemType Directory -Path "test-data" -Force
}

# Run tests based on scenario
switch ($TestScenario.ToLower()) {
    "small" { $results += Test-SmallFileOperations }
    "large" { $results += Test-LargeFileOperations }
    "lightning" { $results += Test-GitZoomLightningPush }
    "network" { $results += Test-NetworkLatency }
    "vscode" { $results += Test-VSCodeIntegration }
    "all" {
        $results += Test-SmallFileOperations
        $results += Test-LargeFileOperations
        $results += Test-GitZoomLightningPush
        $results += Test-NetworkLatency
        $results += Test-VSCodeIntegration
    }
}

# Generate summary report
Write-Host "`n📊 Performance Summary" -ForegroundColor Magenta
Write-Host "=" * 50 -ForegroundColor Gray

$successfulOps = $results | Where-Object { $_.Success -eq $true }
$avgDuration = ($successfulOps | Measure-Object Duration -Average).Average

Write-Host "Total Operations: $($results.Count)"
Write-Host "Successful: $($successfulOps.Count)"
Write-Host "Failed: $(($results | Where-Object { $_.Success -eq $false }).Count)"
Write-Host "Average Duration: $([math]::Round($avgDuration, 2))ms"

# Show top 3 slowest operations
Write-Host "`n🐌 Slowest Operations:"
$results | Sort-Object Duration -Descending | Select-Object -First 3 | ForEach-Object {
    Write-Host "  $($_.Operation): $($_.Duration)ms" -ForegroundColor Yellow
}

# Show top 3 fastest operations
Write-Host "`n⚡ Fastest Operations:"
$successfulOps | Sort-Object Duration | Select-Object -First 3 | ForEach-Object {
    Write-Host "  $($_.Operation): $($_.Duration)ms" -ForegroundColor Green
}

# Save detailed results if requested
if ($GenerateReport) {
    $reportPath = "experiments/performance-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $results | ConvertTo-Json -Depth 3 | Out-File $reportPath -Encoding UTF8
    Write-Host "`n📄 Detailed report saved to: $reportPath" -ForegroundColor Cyan
}

Write-Host "`n🎯 Optimization Recommendations:" -ForegroundColor Magenta
if ($avgDuration -gt 1000) {
    Write-Host "  • Consider implementing parallel operations" -ForegroundColor Yellow
    Write-Host "  • Add caching for frequently accessed data" -ForegroundColor Yellow
}
if (($results | Where-Object { $_.Operation -like "*Push*" }).Duration -gt 2000) {
    Write-Host "  • Network operations are slow - consider compression" -ForegroundColor Yellow
}

Write-Host "`n✨ Performance testing completed!" -ForegroundColor Green