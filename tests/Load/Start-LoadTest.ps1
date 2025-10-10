<#
.SYNOPSIS
    Simulates concurrent user load on the GitZoom module.
.DESCRIPTION
    Creates multiple PowerShell runspaces to simulate users performing
    git operations in the same repository simultaneously. This helps
    detect race conditions and performance issues under load.
#>
[CmdletBinding()]
param(
    [int]$ConcurrentUsers = 5,
    [int]$OperationsPerUser = 10,
    [string]$TestRepoPath = (Join-Path $env:TEMP "GitZoomLoadTest_$(Get-Random)")
)

Write-Host "Starting Load Test with $ConcurrentUsers concurrent users..." -ForegroundColor Cyan

# 1. Setup Test Environment
if (Test-Path $TestRepoPath) {
    Remove-Item $TestRepoPath -Recurse -Force
}
New-Item -Path $TestRepoPath -ItemType Directory -Force | Out-Null
Set-Location $TestRepoPath
git init | Out-Null
git config user.name "Load Test"
git config user.email "load@test.com"
"Initial file" | Out-File "readme.md"
git add .
git commit -m "Initial commit" | Out-Null

# 2. Define the script for each "user"
$scriptBlock = {
    param($RepoPath, $User, $OpsCount)

    # Import the module in this runspace
    Import-Module (Join-Path $PSScriptRoot '..\..\lib\GitZoom.psm1') -Force

    Set-Location $RepoPath
    $results = @()

    for ($i = 1; $i -le $OpsCount; $i++) {
        $opType = Get-Random -InputObject 'commit', 'status', 'history'
        $startTime = Get-Date

        try {
            switch ($opType) {
                'commit' {
                    $content = "User $User op $i"
                    $fileName = "file-$User-$i.txt"
                    $content | Out-File $fileName
                    Save-Changes -Message "Commit from $User op $i" -All
                }
                'status' {
                    Get-GitStatus | Out-Null
                }
                'history' {
                    Get-GitHistory -Limit 5 | Out-Null
                }
            }
            $success = $true
            $error = $null
        } catch {
            $success = $false
            $error = $_.Exception.Message
        }

        $duration = (Get-Date) - $startTime
        $results += [PSCustomObject]@{
            User = $User
            Operation = $opType
            DurationMS = $duration.TotalMilliseconds
            Success = $success
            Error = $error
        }
    }
    return $results
}

# 3. Create and run jobs for each user
$jobs = @()
1..$ConcurrentUsers | ForEach-Object {
    $jobs += Start-Job -ScriptBlock $scriptBlock -ArgumentList $TestRepoPath, $_, $OperationsPerUser
}

Write-Host "All user jobs started. Waiting for completion..."
$jobs | Wait-Job | Out-Null

# 4. Collect and analyze results
$allResults = $jobs | Receive-Job
$jobs | Remove-Job

$totalOps = $allResults.Count
$failedOps = ($allResults | Where-Object { -not $_.Success }).Count
$avgDuration = ($allResults.DurationMS | Measure-Object -Average).Average

Write-Host "`n========== Load Test Summary ==========" -ForegroundColor Cyan
Write-Host "Concurrent Users: $ConcurrentUsers"
Write-Host "Operations Per User: $OperationsPerUser"
Write-Host "Total Operations: $totalOps"
Write-Host "Successful Operations: $($totalOps - $failedOps)" -ForegroundColor Green
Write-Host "Failed Operations: $failedOps" -ForegroundColor $(if ($failedOps -gt 0) { 'Red' } else { 'Green' })
Write-Host "Average Operation Duration: $([math]::Round($avgDuration, 2)) ms"

if ($failedOps -gt 0) {
    Write-Host "`nFailed Operations Details:" -ForegroundColor Yellow
    $allResults | Where-Object { -not $_.Success } | Format-Table
    exit 1
}

# 5. Cleanup
Set-Location $PSScriptRoot
Remove-Item $TestRepoPath -Recurse -Force
Write-Host "`nLoad test completed successfully." -ForegroundColor Green
