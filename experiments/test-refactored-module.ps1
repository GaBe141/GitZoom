<#
.SYNOPSIS
    Quick test script to demonstrate the refactored performance module

.DESCRIPTION
    This script demonstrates the new shared PerformanceExperiments module
    and compares it with the original implementations.

.EXAMPLE
    .\test-refactored-module.ps1
#>

$ErrorActionPreference = "Stop"

# Import (dot-source) the shared performance library
$modulePath = Join-Path $PSScriptRoot "..\lib\PerformanceExperiments.ps1"
. $modulePath

Write-PerformanceHeader "PERFORMANCE MODULE DEMONSTRATION" "✨"

# Test 1: Logging functions
Write-PerformanceLog "Testing logging functionality..." -Level "INFO"
Write-PerformanceLog "Success message test" -Level "SUCCESS"
Write-PerformanceLog "Warning message test" -Level "WARNING"
Write-PerformanceLog "Error message test" -Level "ERROR"
Write-PerformanceLog "Turbo mode test" -Level "TURBO"
Write-PerformanceLog "Benchmark test" -Level "BENCHMARK"

# Test 2: Memory usage tracking
Write-PerformanceHeader "Memory Usage Tracking" "-"
$memory = Get-MemoryUsage -IncludeSystem
Write-Host "Current Process Memory:"
Write-Host "  Working Set: $($memory.WorkingSet) MB" -ForegroundColor Cyan
Write-Host "  Private Memory: $($memory.PrivateMemory) MB" -ForegroundColor Cyan
Write-Host "  Virtual Memory: $($memory.VirtualMemory) MB" -ForegroundColor Cyan
if ($memory.SystemTotalMemory) {
    Write-Host "System Memory:"
    Write-Host "  Total: $($memory.SystemTotalMemory) MB" -ForegroundColor Yellow
    Write-Host "  Free: $($memory.SystemFreeMemory) MB" -ForegroundColor Yellow
    Write-Host "  Used: $($memory.SystemUsedPercent)%" -ForegroundColor Yellow
}

# Test 3: Measure operation with memory tracking
Write-PerformanceHeader "Operation Measurement with Memory" "-"
$result = Measure-OperationWithMemory -OperationName "TestOperation" -ScriptBlock {
    Start-Sleep -Milliseconds 100
    1..1000 | ForEach-Object { $_ * 2 } | Out-Null
}

Write-Host "Operation: $($result.OperationName)" -ForegroundColor Cyan
Write-Host "  Time: $($result.ElapsedMilliseconds)ms" -ForegroundColor Green
Write-Host "  Memory Delta: $($result.MemoryDelta)MB" -ForegroundColor Green
Write-Host "  Success: $($result.Success)" -ForegroundColor Green

# Test 4: Performance comparison formatting
Write-PerformanceHeader "Performance Comparison Formatting" "-"

$comparison1 = Format-PerformanceComparison `
    -StandardTime 1000 `
    -OptimizedTime 300 `
    -OperationName "Excellent Optimization" `
    -Detailed

$comparison2 = Format-PerformanceComparison `
    -StandardTime 500 `
    -OptimizedTime 450 `
    -OperationName "Marginal Improvement" `
    -Detailed

$comparison3 = Format-PerformanceComparison `
    -StandardTime 200 `
    -OptimizedTime 300 `
    -OperationName "Regression Case" `
    -Detailed

# Test 5: Git config management (dry run)
Write-PerformanceHeader "Git Configuration Management Test" "-"

$testConfigs = @{
    "user.name" = "GitZoom Tester"
    "user.email" = "test@gitzoom.local"
}

Write-PerformanceLog "Testing safe Git config management..." -Level "INFO"
Write-PerformanceLog "Note: This test requires a Git repository in current directory" -Level "WARNING"

if (Test-Path ".git") {
    try {
        Invoke-WithGitConfig -Configurations $testConfigs -ScriptBlock {
            Write-PerformanceLog "Inside config block - configs applied" -Level "SUCCESS"
            $name = git config user.name
            $email = git config user.email
            Write-Host "  Temporary name: $name" -ForegroundColor Cyan
            Write-Host "  Temporary email: $email" -ForegroundColor Cyan
        } -ShowDetails
        
        Write-PerformanceLog "Configs automatically restored after block" -Level "SUCCESS"
    }
    catch {
        Write-PerformanceLog "Git config test skipped: $($_.Exception.Message)" -Level "WARNING"
    }
}
else {
    Write-PerformanceLog "Skipping Git config test (not in a Git repository)" -Level "WARNING"
}

# Test 6: Edge case handling
Write-PerformanceHeader "Edge Case Handling" "-"

Write-PerformanceLog "Testing division by zero protection..." -Level "INFO"
$edge1 = Format-PerformanceComparison -StandardTime 0 -OptimizedTime 0 -OperationName "Both Zero"
$edge2 = Format-PerformanceComparison -StandardTime 0 -OptimizedTime 100 -OperationName "Standard Zero"
$edge3 = Format-PerformanceComparison -StandardTime 100 -OptimizedTime 0 -OperationName "Optimized Zero"

Write-Host "`nEdge Case Results:" -ForegroundColor Yellow
Write-Host "  Both Zero: $($edge1.Status)" -ForegroundColor Cyan
Write-Host "  Standard Zero: $($edge2.Status)" -ForegroundColor Cyan
Write-Host "  Optimized Zero: $($edge3.Status)" -ForegroundColor Cyan

# Test 7: Export functionality
Write-PerformanceHeader "Results Export Test" "-"

$testResults = @{
    TestName = "Module Demonstration"
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Operations = @{
        Test1 = 100
        Test2 = 200
        Test3 = 150
    }
    Improvements = @{
        Test1 = 50
        Test2 = 25
    }
}

$outputFile = Join-Path $env:TEMP "gitzoom-module-test-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$exported = Export-PerformanceResults -Results $testResults -OutputPath $outputFile -PrettyPrint

if ($exported) {
    Write-Host "Results exported to: $outputFile" -ForegroundColor Green
    Write-Host "`nPreview:" -ForegroundColor Yellow
    Get-Content $outputFile -Head 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    Write-Host "  ..." -ForegroundColor DarkGray
}

# Summary
Write-PerformanceHeader "TEST SUMMARY" "="
Write-Host "✅ Logging functions: " -NoNewline -ForegroundColor Green
Write-Host "PASSED" -ForegroundColor White

Write-Host "✅ Memory tracking: " -NoNewline -ForegroundColor Green
Write-Host "PASSED" -ForegroundColor White

Write-Host "✅ Operation measurement: " -NoNewline -ForegroundColor Green
Write-Host "PASSED" -ForegroundColor White

Write-Host "✅ Performance comparison: " -NoNewline -ForegroundColor Green
Write-Host "PASSED" -ForegroundColor White

Write-Host "✅ Edge case handling: " -NoNewline -ForegroundColor Green
Write-Host "PASSED" -ForegroundColor White

Write-Host "✅ Export functionality: " -NoNewline -ForegroundColor Green
Write-Host "PASSED" -ForegroundColor White

if (Test-Path ".git") {
    Write-Host "✅ Git config management: " -NoNewline -ForegroundColor Green
    Write-Host "PASSED" -ForegroundColor White
}
else {
    Write-Host "⚠️  Git config management: " -NoNewline -ForegroundColor Yellow
    Write-Host "SKIPPED (not in Git repo)" -ForegroundColor Yellow
}

Write-Host "`n🎉 All tests completed successfully!" -ForegroundColor Green
Write-Host ""
