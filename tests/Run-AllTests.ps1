<#
.SYNOPSIS
    Runs all GitZoom tests using Pester 5.x

.DESCRIPTION
    This script discovers and runs all Pester tests in the tests directory
    using modern Pester 5.x syntax and generates test results.

.PARAMETER OutputPath
    Path where test results should be saved (default: TestResults.xml)

.PARAMETER Coverage
    Generate code coverage report

.EXAMPLE
    .\Run-AllTests.ps1

.EXAMPLE
    .\Run-AllTests.ps1 -Coverage -OutputPath "coverage.xml"
#>

[CmdletBinding()]
param(
    [string]$OutputPath = "TestResults.xml",
    [switch]$Coverage
)

# Ensure we're in the correct directory
$ScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
$ProjectRoot = Split-Path $ScriptRoot -Parent
Push-Location $ProjectRoot

try {
    # Import GitZoom module
    Write-Host "🔧 Importing GitZoom module..." -ForegroundColor Cyan
    Import-Module ./lib/GitZoom.psd1 -Force -ErrorAction Stop

    # Configure Pester configuration
    $pesterConfig = @{
        Run = @{
            Path = "./tests"
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
    }

    # Add code coverage if requested
    if ($Coverage) {
        $pesterConfig.CodeCoverage = @{
            Enabled = $true
            OutputPath = "Coverage.xml"
            OutputFormat = "JaCoCo"
            Path = "./lib"
        }
    }

    # Run tests
    Write-Host "🧪 Running GitZoom tests..." -ForegroundColor Cyan
    $result = Invoke-Pester -Configuration $pesterConfig

    # Display results
    Write-Host "`n📊 Test Results:" -ForegroundColor Yellow
    Write-Host "   Passed: $($result.PassedCount)" -ForegroundColor Green
    Write-Host "   Failed: $($result.FailedCount)" -ForegroundColor Red
    Write-Host "   Skipped: $($result.SkippedCount)" -ForegroundColor Yellow
    Write-Host "   Total: $($result.TotalCount)" -ForegroundColor Cyan

    # Exit with appropriate code
    if ($result.FailedCount -gt 0) {
        Write-Host "`n❌ Tests failed!" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "`n✅ All tests passed!" -ForegroundColor Green
        exit 0
    }

} catch {
    Write-Host "❌ Error running tests: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}
