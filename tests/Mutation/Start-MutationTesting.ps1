<#
.SYNOPSIS
    Performs mutation testing on the GitZoom module.
.DESCRIPTION
    Introduces small changes (mutations) into the source code and runs
    Pester tests to see if they detect the change. A high "kill rate"
    indicates a robust test suite.
#>
[CmdletBinding()]
param(
    [string]$SourcePath = (Join-Path $PSScriptRoot '..\lib\GitZoom.psm1'),
    [string]$TestPath = (Join-Path $PSScriptRoot 'Unit'),
    [switch]$VerboseOutput
)

# Import mutation logic
. (Join-Path $PSScriptRoot 'mutators.ps1')

Write-Host "Starting Mutation Testing for GitZoom..." -ForegroundColor Cyan

# 1. Get original source code content
$originalContent = Get-Content -Path $SourcePath -Raw
$tempSourcePath = [System.IO.Path]::GetTempFileName()
$originalContent | Out-File $tempSourcePath -Encoding utf8

# 2. Find all possible mutations
$mutations = Find-Mutations -ScriptContent $originalContent
$totalMutations = $mutations.Count
Write-Host "Found $totalMutations possible mutation points."

$killedCount = 0
$survivedMutants = @()
$mutationIndex = 0

# 3. Loop through each mutation
foreach ($mutation in $mutations) {
    $mutationIndex++
    $progress = [math]::Round(($mutationIndex / $totalMutations) * 100)
    Write-Progress -Activity "Running Mutation Tests" -Status "Mutation $mutationIndex of $totalMutations ($progress%)" -PercentComplete $progress

    # Apply the mutation
    $mutatedContent = $originalContent.Remove($mutation.Start, $mutation.Length).Insert($mutation.Start, $mutation.NewValue)
    $mutatedContent | Out-File -FilePath $SourcePath -Encoding utf8 -Force

    # Run Pester tests against the mutated code
    $pesterConfig = New-PesterConfiguration
    $pesterConfig.Run.Path = $TestPath
    $pesterConfig.Run.Exit = $false
    $pesterConfig.Output.Verbosity = 'Minimal'

    $testResult = Invoke-Pester -Configuration $pesterConfig

    # Check if the mutant was killed
    if ($testResult.FailedCount -gt 0) {
        $killedCount++
        if ($VerboseOutput) {
            Write-Host "  [✓ KILLED] Mutation $mutationIndex/$totalMutations at line $($mutation.Line)" -ForegroundColor Green
        }
    } else {
        $survivedMutants += $mutation
        Write-Host "  [✗ SURVIVED] Mutation $mutationIndex/$totalMutations at line $($mutation.Line): '$($mutation.OriginalValue)' -> '$($mutation.NewValue)'" -ForegroundColor Red
    }

    # Revert the change
    $originalContent | Out-File -FilePath $SourcePath -Encoding utf8 -Force
}

# 4. Restore original file and clean up
Remove-Item $tempSourcePath -Force

# 5. Report results
$mutationScore = [math]::Round(($killedCount / $totalMutations) * 100, 2)
Write-Host "`n========== Mutation Test Summary ==========" -ForegroundColor Cyan
Write-Host "Total Mutations: $totalMutations"
Write-Host "Mutants Killed: $killedCount" -ForegroundColor Green
Write-Host "Mutants Survived: $($survivedMutants.Count)" -ForegroundColor Red
Write-Host "Mutation Score: $mutationScore%" -ForegroundColor $(if ($mutationScore -ge 80) { 'Green' } else { 'Yellow' })

if ($survivedMutants.Count -gt 0) {
    Write-Host "`nSurvived Mutants Details:" -ForegroundColor Yellow
    $survivedMutants | Format-Table -AutoSize
}

if ($mutationScore -lt 80) {
    exit 1 # Fail for CI/CD pipelines
}
