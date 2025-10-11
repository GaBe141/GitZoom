param(
    [int]$Iterations = 1,
    [string]$OutputDir = "$(Join-Path $PSScriptRoot '..\..\artifacts\performance')"
)

$ErrorActionPreference = 'Stop'

New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null

function Measure-Scenario {
    param(
        [string]$Name,
        [scriptblock]$Action,
        [scriptblock]$Setup = $null,
        [scriptblock]$Teardown = $null
    )

    $scenarioName = $Name
    $results = [System.Collections.Generic.List[object]]::new()
    for ($i = 1; $i -le $Iterations; $i++) {
        if ($scenarioName) { Write-Verbose "Measuring scenario: $scenarioName (iteration $i)" }
        if ($Setup) { & $Setup }

        $procBefore = Get-Process -Id $PID
        $memBefore = $procBefore.WorkingSet64
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            & $Action
            $success = $true
            $errorMsg = $null
        } catch {
            $success = $false
            $errorMsg = $_.Exception.Message
        }
        $sw.Stop()
        $procAfter = Get-Process -Id $PID
        $memAfter = $procAfter.WorkingSet64

        if ($Teardown) { & $Teardown }

        $results.Add([pscustomobject]@{
            Scenario   = $scenarioName
            Iteration = $i
            ElapsedMs  = $sw.Elapsed.TotalMilliseconds
            MemBefore  = $memBefore
            MemAfter   = $memAfter
            MemDelta   = ($memAfter - $memBefore)
            Success    = $success
            Error      = $errorMsg
            Timestamp  = (Get-Date).ToString("o")
        })
    }
    return $results
}

# Load scenarios if present
$scenariosFile = Join-Path $PSScriptRoot 'Scenarios.ps1'
if (Test-Path $scenariosFile) {
    . $scenariosFile
} else {
    Write-Verbose "No Scenarios.ps1 found. Create tests/Performance/Scenarios.ps1 to define scenarios."
    $Scenarios = @()
}

$report = @()
foreach ($s in $Scenarios) {
    Write-Verbose "Running scenario: $($s.Name)"
    $res = Measure-Scenario -Name $s.Name -Action $s.Action -Setup $s.Setup -Teardown $s.Teardown
    $summary = [pscustomobject]@{
        Name        = $s.Name
        Iterations  = $Iterations
        AvgMs       = ($res | Measure-Object ElapsedMs -Average).Average
        MedianMs    = ($res | Sort-Object ElapsedMs | Select-Object -ExpandProperty ElapsedMs | Select-Object -Index ([int]([Math]::Floor($res.Count/2))))
        MinMs       = ($res | Measure-Object ElapsedMs -Minimum).Minimum
        MaxMs       = ($res | Measure-Object ElapsedMs -Maximum).Maximum
        AvgMemDelta = ($res | Measure-Object MemDelta -Average).Average
        Details     = $res
    }
    $report += $summary
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outJson = Join-Path $OutputDir "baseline-$timestamp.json"
$outCsv  = Join-Path $OutputDir "baseline-$timestamp.csv"

$report | ConvertTo-Json -Depth 5 | Out-File -FilePath $outJson -Encoding utf8
# Simple CSV summary
$report | Select-Object Name,Iterations,AvgMs,MedianMs,MinMs,MaxMs,AvgMemDelta | Export-Csv -Path $outCsv -NoTypeInformation -Encoding utf8

Write-Host "Performance baseline complete. JSON: $outJson  CSV: $outCsv" -ForegroundColor Green
