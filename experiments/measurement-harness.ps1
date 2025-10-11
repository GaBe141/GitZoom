param(
    [int]$FileCount = 100,
    [string]$Mode = 'baseline' # baseline or tuned
)

$ErrorActionPreference = 'Stop'

function Measure-Run {
    param($Dir, $Num)
    $res = @{}
    Push-Location $Dir
    try {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        git init --quiet 2>$null
        $sw.Stop(); $res.Init = $sw.ElapsedMilliseconds

        $sw.Restart()
        1..$Num | ForEach-Object { [System.IO.File]::WriteAllText("file$_.txt", "Content $_ $(Get-Random)") }
        $sw.Stop(); $res.FileCreation = $sw.ElapsedMilliseconds

        $sw.Restart()
        git add . 2>$null
        $sw.Stop(); $res.Staging = $sw.ElapsedMilliseconds

        $sw.Restart()
        git commit -m "test commit" --quiet 2>$null
        $sw.Stop(); $res.Commit = $sw.ElapsedMilliseconds
    } finally { Pop-Location }
    return $res
}

$workspace = Join-Path $env:TEMP "gitzoom-measure-$(Get-Random)"
if (Test-Path $workspace) { Remove-Item $workspace -Recurse -Force }
New-Item -ItemType Directory -Path $workspace | Out-Null

$results = @{}

if ($Mode -eq 'tuned') {
    # apply tune options to the global repo for testing
    git config --global core.fscache true
    git config --global core.untrackedCache true
    git config --global core.commitGraph true
}

$baselineDir = Join-Path $workspace 'baseline'
New-Item -ItemType Directory -Path $baselineDir | Out-Null
$results.Baseline = Measure-Run -Dir $baselineDir -Num $FileCount

if ($Mode -eq 'tuned') {
    $tunedDir = Join-Path $workspace 'tuned'
    New-Item -ItemType Directory -Path $tunedDir | Out-Null
    $results.Tuned = Measure-Run -Dir $tunedDir -Num $FileCount
}

$outFile = Join-Path (Get-Location) "artifacts" -ErrorAction SilentlyContinue
if (-not $outFile) { $outFile = Join-Path $PWD 'artifacts' }
if (-not (Test-Path $outFile)) { New-Item -Path $outFile -ItemType Directory | Out-Null }

$timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$jsonFile = Join-Path $outFile "measurement-$timestamp.json"
$obj = @{ Mode = $Mode; FileCount = $FileCount; Results = $results; Timestamp = (Get-Date).ToString('o') }
$obj | ConvertTo-Json -Depth 5 | Out-File -Encoding utf8 $jsonFile

Write-Host "Wrote results to $jsonFile"
