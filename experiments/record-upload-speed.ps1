# Record one row of upload (fetch/push) speed to test-results/upload-speed.csv
# Run from repo root: .\experiments\record-upload-speed.ps1
# Optionally: -RepoRoot "C:\path\to\GitZoom"

param(
    [string]$RepoRoot = (Join-Path $PSScriptRoot "..")
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path $RepoRoot).Path

Push-Location $repoRoot
try {
    # Run network benchmark; writes experiments/performance-report-YYYYMMDD-HHMMSS.json
    & (Join-Path $PSScriptRoot "performance-benchmark.ps1") -TestScenario network -GenerateReport | Out-Null

    $reportsDir = Join-Path $repoRoot "experiments"
    $latestReport = Get-ChildItem -Path $reportsDir -Filter "performance-report-*.json" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $latestReport) {
        Write-Host "No performance report found under experiments/. Run the benchmark with -GenerateReport first." -ForegroundColor Yellow
        exit 1
    }

    $data = Get-Content -Path $latestReport.FullName -Raw | ConvertFrom-Json
    $fetchRow = $data | Where-Object { $_.Operation -eq "Git Fetch" } | Select-Object -First 1
    $pushRow = $data | Where-Object { $_.Operation -eq "Git Push" } | Select-Object -First 1

    $fetchMs = if ($fetchRow) { [int]$fetchRow.Duration } else { -1 }
    $pushMs = if ($pushRow) { [int]$pushRow.Duration } else { -1 }
    $fetchSuccess = if ($fetchRow) { $fetchRow.Success.ToString().ToLowerInvariant() } else { "false" }
    $pushSuccess = if ($pushRow) { $pushRow.Success.ToString().ToLowerInvariant() } else { "false" }

    $timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    $scenario = "network"

    $testResultsDir = Join-Path $repoRoot "test-results"
    if (-not (Test-Path $testResultsDir)) {
        New-Item -ItemType Directory -Path $testResultsDir -Force | Out-Null
    }

    $csvPath = Join-Path $testResultsDir "upload-speed.csv"
    $header = "timestamp_utc,scenario,fetch_ms,push_ms,fetch_success,push_success"
    $line = "$timestampUtc,$scenario,$fetchMs,$pushMs,$fetchSuccess,$pushSuccess"

    if (-not (Test-Path $csvPath)) {
        $header | Out-File -FilePath $csvPath -Encoding UTF8
    }
    Add-Content -Path $csvPath -Value $line -Encoding UTF8

    Write-Host "Logged fetch=$fetchMs ms, push=$pushMs ms to test-results/upload-speed.csv" -ForegroundColor Cyan
}
finally {
    Pop-Location
}
