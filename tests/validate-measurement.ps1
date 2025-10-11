param(
    [string]$File = "artifacts/measurement-20251012-000223.json"
)

Write-Host "Validating measurement file: $File"

if (-not (Test-Path -Path $File)) {
    Write-Error "File not found: $File"
    exit 2
}

try {
    $json = Get-Content -Raw -Path $File | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse JSON: $_"
    exit 3
}

$errors = @()

if (-not $json.Timestamp) { $errors += 'Missing Timestamp' }
if (-not $json.FileCount) { $errors += 'Missing FileCount' }
if (-not $json.Results) { $errors += 'Missing Results object' }
else {
    # Support two shapes:
    # 1) Results directly contains Init/FileCreation/Staging/Commit
    # 2) Results.Baseline is an array whose last element is an object with those fields
    $resultsObj = $null
    if ($json.Results.Init -or $json.Results.FileCreation -or $json.Results.Staging -or $json.Results.Commit) {
        $resultsObj = $json.Results
    } elseif ($json.Results.Baseline -and ($json.Results.Baseline -is [System.Array])) {
        $maybe = $json.Results.Baseline[-1]
        if ($maybe -is [System.Management.Automation.PSCustomObject] -or $maybe -is [hashtable]) { $resultsObj = $maybe }
    }

    if (-not $resultsObj) { $errors += 'Missing timing object (expected Results.Init etc. or Results.Baseline[...] object)' }
    else {
        if (-not $resultsObj.Init) { $errors += 'Missing Results.Init' }
        if (-not $resultsObj.FileCreation) { $errors += 'Missing Results.FileCreation' }
        if (-not $resultsObj.Staging) { $errors += 'Missing Results.Staging' }
        if (-not $resultsObj.Commit) { $errors += 'Missing Results.Commit' }
    }
}

if ($errors.Count -gt 0) {
    Write-Error "Validation failed:`n$($errors -join "`n")"
    exit 4
}

Write-Host "Measurement JSON validation passed." -ForegroundColor Green
exit 0
