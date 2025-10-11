# Shared Utilities for GitZoom Experiments
# Contains common functions to reduce duplication across experiment scripts

$ErrorActionPreference = "Stop"

function Write-ExperimentLog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Prefix = "EXPERIMENT",
        [hashtable]$ColorMap = @{
            "SUCCESS" = "Green"
            "INFO" = "Cyan"
            "WARNING" = "Yellow"
            "ERROR" = "Red"
        }
    )
    $timestamp = Get-Date -Format "HH:mm:ss.fff"
    $color = $ColorMap[$Level] ?? "Cyan"
    Write-Host "[$timestamp] $Prefix`: $Message" -ForegroundColor $color
}

function Initialize-ExperimentWorkspace {
    param(
        [string]$WorkspaceName,
        [string]$Prefix = "EXPERIMENT",
        [hashtable]$ColorMap = @{
            "SUCCESS" = "Green"
            "INFO" = "Cyan"
            "WARNING" = "Yellow"
            "ERROR" = "Red"
        }
    )
    Write-ExperimentLog "🏗️ INITIALIZING $WorkspaceName SYSTEM" "INFO" $Prefix $ColorMap

    # Create workspace
    $workspacePath = "$env:TEMP\GitZoom$WorkspaceName"
    if (Test-Path $workspacePath) {
        Remove-Item $workspacePath -Recurse -Force
    }
    New-Item -Path $workspacePath -ItemType Directory -Force | Out-Null

    # Optimize directory for Git operations
    try {
        $folder = Get-Item $workspacePath
        $folder.Attributes = $folder.Attributes -bor [System.IO.FileAttributes]::NotContentIndexed
        Write-ExperimentLog "$WorkspaceName workspace optimized: $workspacePath" "SUCCESS" $Prefix $ColorMap
    } catch {
        Write-ExperimentLog "$WorkspaceName workspace created: $workspacePath" "SUCCESS" $Prefix $ColorMap
    }

    return $workspacePath
}

function Measure-StandardOperations {
    param(
        [int]$NumFiles,
        [string]$Prefix = "EXPERIMENT",
        [hashtable]$ColorMap = @{
            "SUCCESS" = "Green"
            "INFO" = "Cyan"
            "WARNING" = "Yellow"
            "ERROR" = "Red"
        },
        [ref]$Results
    )

    Write-ExperimentLog "📊 Measuring standard operations ($NumFiles files)..." "INFO" $Prefix $ColorMap

    $testDir = "$env:TEMP\StandardTest"
    if (Test-Path $testDir) { Remove-Item $testDir -Recurse -Force }
    New-Item -Path $testDir -ItemType Directory -Force | Out-Null

    Push-Location $testDir
    try {
        # Standard init
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        git init --quiet 2>$null
        $timer.Stop()
        $Results.Value.StandardOps.Init = $timer.ElapsedMilliseconds

        # Standard file creation
        $timer.Restart()
        1..$NumFiles | ForEach-Object {
            $content = "File $_ content: $(Get-Random)"
            [System.IO.File]::WriteAllText("file$_.txt", $content)
        }
        $timer.Stop()
        $Results.Value.StandardOps.FileCreation = $timer.ElapsedMilliseconds

        # Standard staging
        $timer.Restart()
        git add . 2>$null
        $timer.Stop()
        $Results.Value.StandardOps.Staging = $timer.ElapsedMilliseconds

        # Standard commit
        $timer.Restart()
        git commit -m "Standard commit" --quiet 2>$null
        $timer.Stop()
        $Results.Value.StandardOps.Commit = $timer.ElapsedMilliseconds

        Write-ExperimentLog "Standard operations complete - Staging: $($Results.Value.StandardOps.Staging)ms" "INFO" $Prefix $ColorMap

    } finally {
        Pop-Location
        if (Test-Path $testDir) { Remove-Item $testDir -Recurse -Force }
    }
}

function Apply-GitConfigs {
    param([hashtable]$Configs)
    foreach ($config in $Configs.GetEnumerator()) {
        git config $config.Key $config.Value 2>$null
    }
}