<#
.SYNOPSIS
    Generates visual test and performance reports for GitZoom.
.DESCRIPTION
    Reads historical TestResults and Performance-Results JSON and creates
    an HTML report with charts (Chart.js) to visualize trends.
#>
[CmdletBinding()]
param(
    [string]$PerformanceHistoryPath = (Join-Path $PSScriptRoot '..\Performance\Performance-Results.json'),
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\Reports\Performance-Report.html')
)

if (-not (Test-Path $PerformanceHistoryPath)) {
    Write-Host "No performance history found at $PerformanceHistoryPath" -ForegroundColor Yellow
    exit 1
}

$history = Get-Content $PerformanceHistoryPath | ConvertFrom-Json

# Prepare data for Chart.js
$dates = $history | ForEach-Object { $_.Date }
$durations = $history | ForEach-Object { $_.Duration }
$passRates = $history | ForEach-Object { if ($_.TotalTests -gt 0) { [math]::Round(( ($_.PassedTests / $_.TotalTests) * 100), 2) } else { 0 } }

$chartData = @{
    Dates = $dates
    Durations = $durations
    PassRates = $passRates
}

$chartJson = $chartData | ConvertTo-Json -Compress

# Create output directory
$outputDir = Split-Path $OutputPath -Parent
if (-not (Test-Path $outputDir)) { New-Item -Path $outputDir -ItemType Directory -Force | Out-Null }

# HTML with embedded Chart.js
$html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset='utf-8' />
    <title>GitZoom Visual Reports</title>
    <script src='https://cdn.jsdelivr.net/npm/chart.js'></script>
    <style> body { font-family: Arial, sans-serif; margin: 20px; } .chart { max-width: 900px; }</style>
</head>
<body>
    <h1>GitZoom Visual Reports</h1>
    <canvas id='durationChart' class='chart' width='900' height='300'></canvas>
    <canvas id='passRateChart' class='chart' width='900' height='300'></canvas>

    <script>
        const data = $chartJson;

        const ctx1 = document.getElementById('durationChart').getContext('2d');
        new Chart(ctx1, {
            type: 'line',
            data: {
                labels: data.Dates,
                datasets: [{
                    label: 'Test Duration (s)',
                    data: data.Durations,
                    borderColor: 'rgba(75, 192, 192, 1)',
                    tension: 0.1,
                    fill: false
                }]
            }
        });

        const ctx2 = document.getElementById('passRateChart').getContext('2d');
        new Chart(ctx2, {
            type: 'bar',
            data: {
                labels: data.Dates,
                datasets: [{
                    label: 'Pass Rate (%)',
                    data: data.PassRates,
                    backgroundColor: 'rgba(54, 162, 235, 0.5)'
                }]
            }
        });
    </script>
</body>
</html>
"@

$html | Out-File $OutputPath -Encoding UTF8
Write-Host "Generated visual report at: $OutputPath" -ForegroundColor Green

if ($IsWindows) { Start-Process $OutputPath }
