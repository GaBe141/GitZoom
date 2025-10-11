# Define scenarios as an array of hashtables: Name, Action (scriptblock), optional Setup/Teardown

$Scenarios = @()

# Scenario: Quick status scan of the current workspace using Get-GitStatusAll if available
if (Get-Command -Name Get-GitStatusAll -ErrorAction SilentlyContinue) {
    $Scenarios += [pscustomobject]@{
        Name = 'Get-GitStatusAll_Workspace'
        Action = { Get-GitStatusAll -Path (Get-Location) | Out-Null }
        Setup = $null
        Teardown = $null
    }
}

# Scenario: Run an isolated git fetch against a single repo (this will call git fetch and may require credentials)
$Scenarios += [pscustomobject]@{
    Name = 'GitFetch_Self'
    Action = {
        Push-Location -Path (Split-Path -Parent $MyInvocation.MyCommand.Path)
        try {
            if (Test-Path .git) { git fetch --all --prune | Out-Null }
        } finally { Pop-Location }
    }
    Setup = $null
    Teardown = $null
}

# Scenario: No-op to measure harness overhead
$Scenarios += [pscustomobject]@{
    Name = 'NoOp'
    Action = { Start-Sleep -Milliseconds 50 }
    Setup = $null
    Teardown = $null
}

# --- Parallel vs Serial fetch demo ---
# Discover up to N local git repos under the repository root or tests/test-data
$RepoSearchRoots = @(
    (Resolve-Path -LiteralPath $PSScriptRoot -ErrorAction SilentlyContinue).ProviderPath,
    (Join-Path (Resolve-Path -LiteralPath $PSScriptRoot -ErrorAction SilentlyContinue).ProviderPath '..' 'test-data')
)

$Discovered = @()
foreach ($root in $RepoSearchRoots) {
    if (-not $root) { continue }
    try {
        $found = Get-ChildItem -Path $root -Directory -Recurse -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName '.git') } |
            Select-Object -First 10 -ExpandProperty FullName
        $Discovered += $found
    } catch {
        Write-Verbose "Repo discovery under $root failed: $($_.Exception.Message)"
    }
}

$Discovered = $Discovered | Select-Object -Unique

# If too few discovered repos, simulate additional repo paths to reach 20
if ($Discovered.Count -lt 20) {
    for ($i = $Discovered.Count; $i -lt 20; $i++) {
        $Discovered += (Join-Path (Resolve-Path -LiteralPath $PSScriptRoot).ProviderPath "simulated-repo-$i")
    }
}

# Ensure repository root (two levels up from this script) is included when it contains a .git
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..') -ErrorAction SilentlyContinue).ProviderPath
if ($repoRoot -and (Test-Path (Join-Path $repoRoot '.git')) -and ($Discovered -notcontains $repoRoot)) {
    $Discovered += $repoRoot
}

# If still too few discovered repos, allow the demo to run with whatever we have (including 1)

# Helper to simulate network fetch (sleep per repo) or run real fetch when env var set
function Invoke-DemoFetch {
    param(
        [string[]]$Paths,
        [switch]$Parallel
    )
    $allowReal = $env:GITZOOM_PERF_ALLOW_FETCH -eq '1'
    if ($allowReal -and (Get-Command -Name Invoke-GitFetchAll -ErrorAction SilentlyContinue)) {
        if ($Parallel) {
            Invoke-GitFetchAll -Path $Paths -MaxParallel 8 -TimeoutSeconds 60 | Out-Null
        } else {
            foreach ($p in $Paths) { Push-Location $p; git fetch --all --prune | Out-Null; Pop-Location }
        }
        return
    }

    # Tuned simulation: each repo 'fetch' sleeps a random 800-1600ms to better show parallelism benefits
    if ($Parallel) {
        # Prefer Start-ThreadJob for lower overhead when available
        if (Get-Command -Name Start-ThreadJob -ErrorAction SilentlyContinue) {
            $jobs = @()
            foreach ($p in $Paths) {
                $jobs += Start-ThreadJob -ScriptBlock { Start-Sleep -Milliseconds (Get-Random -Minimum 800 -Maximum 1600) }
            }
            $jobs | Wait-Job | Out-Null
            $jobs | Receive-Job | Out-Null
            $jobs | Remove-Job -Force
        } elseif ($PSVersionTable.PSEdition -eq 'Core' -and $PSVersionTable.PSVersion.Major -ge 7) {
            # Use ForEach-Object -Parallel on PowerShell 7+ for efficient parallelism
            $Paths | ForEach-Object -Parallel { Start-Sleep -Milliseconds (Get-Random -Minimum 800 -Maximum 1600) } -ThrottleLimit 8
        } else {
            # Fallback to Start-Job (higher overhead)
            $jobs = @()
            foreach ($p in $Paths) {
                $jobs += Start-Job -ScriptBlock { Start-Sleep -Milliseconds (Get-Random -Minimum 800 -Maximum 1600) }
            }
            $jobs | Wait-Job | Out-Null
            $jobs | Remove-Job -Force
        }
    } else {
        foreach ($p in $Paths) { Start-Sleep -Milliseconds (Get-Random -Minimum 800 -Maximum 1600) }
    }
}

if ($Discovered.Count -ge 1) {
    $paths = $Discovered

    $Scenarios += [pscustomobject]@{
        Name = 'Parallel-Fetch-Demo'
        Action = { Invoke-DemoFetch -Paths $paths -Parallel }
        Setup = $null
        Teardown = $null
    }

    $Scenarios += [pscustomobject]@{
        Name = 'Serial-Fetch-Demo'
        Action = { Invoke-DemoFetch -Paths $paths }
        Setup = $null
        Teardown = $null
    }
}
