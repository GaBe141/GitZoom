#!/usr/bin/env pwsh
# PowerShell pre-commit hook (actual script)
param()
$ErrorActionPreference = 'Stop'

# Get staged files (added/modified/copied)
$staged = git diff --cached --name-only --diff-filter=ACM
if (-not $staged) { exit 0 }

# If we're installing/updating hooks themselves, skip analysis to avoid bootstrap problems
if ($staged -match '^\.githooks[\\/]' -or $staged -match '\.githooks[\\/]') {
    Write-Host "Staged changes include .githooks files; skipping pre-commit analysis to avoid bootstrap issues." -ForegroundColor Yellow
    exit 0
}

# PowerShell files to analyze, ignore files under .githooks to avoid self-analysis during hook installation
$psFiles = $staged | Where-Object {
    ($_ -match '\.(ps1|psm1|psd1)$') -and
    ($_ -notlike '.githooks/*') -and
    ($_ -notlike '.githooks\\*') -and
    ($_ -notlike './.githooks/*') -and
    ($_ -notlike '.\\githooks\\*')
}

if ($psFiles) {
    Write-Host "Running PSScriptAnalyzer on staged PowerShell files..." -ForegroundColor Cyan
    try {
        Import-Module PSScriptAnalyzer -ErrorAction Stop
    } catch {
        Write-Host "PSScriptAnalyzer not installed. Install with: Install-Module PSScriptAnalyzer -Scope CurrentUser" -ForegroundColor Yellow
        # Don't block commit if analyzer is not installed
        exit 0
    }

    $fail = $false
    foreach ($f in $psFiles) {
        # Only analyze the staged version: use git show to extract staged content
        $content = git show :$f 2>$null
        if (-not $content) { continue }

        $temp = [System.IO.Path]::GetTempFileName() + '.ps1'
        Set-Content -Path $temp -Value $content -Encoding UTF8
        $results = Invoke-ScriptAnalyzer -Path $temp -Severity Error -Recurse:$false
        Remove-Item -Path $temp -Force
        if ($results) {
            Write-Host "PSScriptAnalyzer errors in $f" -ForegroundColor Red
            $results | Format-Table -AutoSize
            $fail = $true
        }
    }
    if ($fail) { Write-Host "Pre-commit: static analysis failed." -ForegroundColor Red; exit 1 }
}

# Run quick unit tests if any test files changed
$testFiles = $staged | Where-Object { $_ -match 'tests\\Unit' }
if ($testFiles) {
    Write-Host "Running quick unit tests (changed tests)..." -ForegroundColor Cyan
    # Tag fast tests with -Tag Fast in your test suite; fallback to run all unit tests
    try {
        Invoke-Pester -Path tests/Unit -Tag Fast -Output Detailed -ErrorAction Stop
    } catch {
        # If fast tag doesn't exist or tests fail, fallback to running all unit tests quickly
        try { Invoke-Pester -Path tests/Unit -Output Detailed -ErrorAction Stop } catch { Write-Host "Unit tests failed." -ForegroundColor Red; exit 1 }
    }
}

# All good
exit 0
