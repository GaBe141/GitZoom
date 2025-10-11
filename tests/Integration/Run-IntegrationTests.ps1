<#
.SYNOPSIS
    Runner script for all GitZoom integration tests

.DESCRIPTION
    Executes the complete integration test suite and generates reports.
    
.PARAMETER Suite
    Specific test suite to run (LargeRepo, BinaryFiles, All)
    
.PARAMETER IncludePerformance
    Include detailed performance metrics
    
.PARAMETER OutputPath
    Path for test results output
#>

[CmdletBinding()]
param(
    [ValidateSet("All", "LargeRepo", "BinaryFiles", "Submodules", "EdgeCases")]
    [string]$Suite = "All",
    
    [switch]$IncludePerformance,
    
    [string]$OutputPath = "IntegrationTestResults.xml"
)

$ScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
$ProjectRoot = Split-Path (Split-Path $ScriptRoot -Parent) -Parent

Push-Location $ProjectRoot

try {
    Write-Host "🧪 GitZoom Integration Test Suite" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Import module
    Write-Host "📦 Importing GitZoom module..." -ForegroundColor Yellow
    Import-Module ./lib/GitZoom.psd1 -Force -ErrorAction Stop
    
    # Determine which tests to run
    $testPath = "./tests/Integration"
    
    if ($Suite -ne "All") {
        switch ($Suite) {
            "LargeRepo" { $testPath = "./tests/Integration/Test-LargeRepository.Tests.ps1" }
            "BinaryFiles" { $testPath = "./tests/Integration/Test-BinaryFiles.Tests.ps1" }
            "Submodules" { $testPath = "./tests/Integration/Test-Submodules.Tests.ps1" }
            "EdgeCases" { $testPath = "./tests/Integration/Test-EdgeCases.Tests.ps1" }
        }
    }
    
    # Configure Pester
    $pesterConfig = @{
        Run = @{
            Path = $testPath
            PassThru = $true
        }
        Output = @{
            Verbosity = "Detailed"
        }
        TestResult = @{
            Enabled = $true
            OutputPath = $OutputPath
            OutputFormat = "NUnitXml"
        }
        Filter = @{
            Tag = "Integration"
        }
    }
    
    # Run tests
    Write-Host "🚀 Running integration tests..." -ForegroundColor Yellow
    Write-Host ""
    
    $result = Invoke-Pester -Configuration $pesterConfig
    
    # Display results
    Write-Host ""
    Write-Host "📊 Integration Test Results:" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    Write-Host "   Passed:  $($result.PassedCount)" -ForegroundColor Green
    Write-Host "   Failed:  $($result.FailedCount)" -ForegroundColor Red
    Write-Host "   Skipped: $($result.SkippedCount)" -ForegroundColor Yellow
    Write-Host "   Total:   $($result.TotalCount)" -ForegroundColor White
    Write-Host ""
    Write-Host "   Duration: $($result.Duration)" -ForegroundColor Gray
    Write-Host ""
    
    if ($IncludePerformance) {
        Write-Host "⚡ Performance Summary:" -ForegroundColor Cyan
        Write-Host "======================" -ForegroundColor Cyan
        
        # Calculate average test duration
        $avgDuration = $result.Duration.TotalMilliseconds / $result.TotalCount
        Write-Host "   Average test duration: $([math]::Round($avgDuration, 2))ms" -ForegroundColor Yellow
        
        # Find slowest tests
        $slowTests = $result.Tests | 
            Where-Object { $_.Result -eq 'Passed' } |
            Sort-Object Duration -Descending |
            Select-Object -First 5
        
        if ($slowTests) {
            Write-Host ""
            Write-Host "   Top 5 slowest tests:" -ForegroundColor Yellow
            $slowTests | ForEach-Object {
                $durationMs = [math]::Round($_.Duration.TotalMilliseconds, 2)
                Write-Host "     - $($_.Name): ${durationMs}ms" -ForegroundColor Gray
            }
        }
    }
    
    # Generate summary report
    if ($result.FailedCount -gt 0) {
        Write-Host ""
        Write-Host "❌ Failed Tests:" -ForegroundColor Red
        $result.Tests | Where-Object { $_.Result -eq 'Failed' } | ForEach-Object {
            Write-Host "   - $($_.Name)" -ForegroundColor Red
            Write-Host "     Error: $($_.ErrorRecord.Exception.Message)" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    
    # Exit with appropriate code
    if ($result.FailedCount -gt 0) {
        Write-Host "❌ Integration tests failed!" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "✅ All integration tests passed!" -ForegroundColor Green
        exit 0
    }
    
} catch {
    Write-Host "❌ Error running integration tests: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    exit 1
} finally {
    Pop-Location
}
