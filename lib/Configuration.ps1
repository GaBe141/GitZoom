<#
.SYNOPSIS
    GitZoom Configuration Management Module
    
.DESCRIPTION
    Handles configuration loading, saving, and management for GitZoom.
    Provides user preferences, performance tuning, and feature toggles.
#>

#region Configuration Management

<#
.SYNOPSIS
    Gets the current GitZoom configuration
    
.DESCRIPTION
    Loads and returns the current GitZoom configuration from the repository
    or creates default configuration if none exists.
    
.PARAMETER Path
    Path to the Git repository. Defaults to current directory.
    
.EXAMPLE
    Get-GitZoomConfig
    
.EXAMPLE
    Get-GitZoomConfig -Path "C:\MyProject"
#>
function Get-GitZoomConfig {
    [CmdletBinding()]
    param(
        [string]$Path = (Get-Location)
    )
    
    try {
        Push-Location $Path
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if (-not $gitRoot -or $LASTEXITCODE -ne 0) {
            throw "Not a valid Git repository"
        }
        
        $configFile = Join-Path $gitRoot ".gitzoom"
        
        if (Test-Path $configFile) {
            $config = Get-Content $configFile | ConvertFrom-Json
            
            # Convert to hashtable for easier manipulation
            $configHash = @{}
            $config.PSObject.Properties | ForEach-Object {
                $configHash[$_.Name] = $_.Value
            }
            
            return $configHash
        }
        else {
            # Return default configuration
            return Get-DefaultConfig
        }
    }
    catch {
        Write-Error "Failed to get GitZoom configuration: $($_.Exception.Message)"
        return Get-DefaultConfig
    }
    finally {
        Pop-Location
    }
}

<#
.SYNOPSIS
    Sets GitZoom configuration values
    
.DESCRIPTION
    Updates GitZoom configuration and saves it to the repository.
    Validates configuration values and provides error handling.
    
.PARAMETER Settings
    Hashtable of settings to update
    
.PARAMETER Path
    Path to the Git repository. Defaults to current directory.
    
.EXAMPLE
    Set-GitZoomConfig -Settings @{ "Performance.BatchSize" = 100 }
    
.EXAMPLE
    $config = @{
        "Features.BatchOperations" = $true
        "Performance.MaxFileThreshold" = 200
    }
    Set-GitZoomConfig -Settings $config
#>
function Set-GitZoomConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Settings,
        
        [string]$Path = (Get-Location)
    )
    
    try {
        Push-Location $Path
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if (-not $gitRoot -or $LASTEXITCODE -ne 0) {
            throw "Not a valid Git repository"
        }
        
        $configFile = Join-Path $gitRoot ".gitzoom"
        $config = Get-GitZoomConfig -Path $Path
        
        # Update configuration with new settings
        foreach ($setting in $Settings.GetEnumerator()) {
            $keyParts = $setting.Key -split '\.'
            $currentLevel = $config
            
            # Navigate to the correct nested level
            for ($i = 0; $i -lt $keyParts.Count - 1; $i++) {
                $key = $keyParts[$i]
                if (-not $currentLevel.ContainsKey($key)) {
                    $currentLevel[$key] = @{}
                }
                $currentLevel = $currentLevel[$key]
            }
            
            # Set the final value
            $finalKey = $keyParts[-1]
            $currentLevel[$finalKey] = $setting.Value
            
            Write-Verbose "Updated $($setting.Key) = $($setting.Value)"
        }
        
        # Validate configuration
        $validation = Test-GitZoomConfig -Config $config
        if (-not $validation.IsValid) {
            throw "Invalid configuration: $($validation.Errors -join '; ')"
        }
        
        # Save configuration
        $config | ConvertTo-Json -Depth 4 | Set-Content $configFile -Encoding UTF8
        
        Write-Verbose "Configuration saved successfully"
    }
    catch {
        Write-Error "Failed to set GitZoom configuration: $($_.Exception.Message)"
        throw
    }
    finally {
        Pop-Location
    }
}

<#
.SYNOPSIS
    Gets the default GitZoom configuration
    
.DESCRIPTION
    Returns the default configuration values for GitZoom.
    Used when no configuration file exists or as a fallback.
    
.EXAMPLE
    Get-DefaultConfig
#>
function Get-DefaultConfig {
    [CmdletBinding()]
    param()
    
    return @{
        Version = "1.0.0"
        InitializedAt = Get-Date
        Repository = ""
        Features = @{
            BatchOperations = $true
            IntelligentStaging = $true
            PerformanceTracking = $true
            OptimizedCommits = $true
            AutoOptimization = $true
            SmartCaching = $true
        }
        Performance = @{
            MaxFileThreshold = 100
            BatchSize = 50
            TimeoutSeconds = 30
            ParallelOperations = $true
            MaxParallelJobs = 4
            CacheSize = 1000
        }
        UI = @{
            ShowPerformanceMetrics = $true
            VerboseOutput = $false
            ColorOutput = $true
            ProgressBars = $true
        }
        Git = @{
            AutoPush = $false
            AutoFetch = $false
            DefaultBranch = "main"
            CommitTemplate = ""
        }
        Windows = @{
            UseLongPaths = $true
            UseNTFSCompression = $false
            EnableFileSystemCache = $true
            OptimizeForSSD = $true
        }
    }
}

<#
.SYNOPSIS
    Validates GitZoom configuration
    
.DESCRIPTION
    Checks configuration values for validity and returns validation results.
    Helps prevent invalid configurations that could cause errors.
    
.PARAMETER Config
    Configuration hashtable to validate
    
.EXAMPLE
    Test-GitZoomConfig -Config $config
#>
function Test-GitZoomConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )
    
    $errors = @()
    $warnings = @()
    
    try {
        # Validate Performance settings
        if ($Config.Performance) {
            $perf = $Config.Performance
            
            if ($perf.BatchSize -and ($perf.BatchSize -lt 1 -or $perf.BatchSize -gt 1000)) {
                $errors += "BatchSize must be between 1 and 1000"
            }
            
            if ($perf.MaxFileThreshold -and ($perf.MaxFileThreshold -lt 1 -or $perf.MaxFileThreshold -gt 10000)) {
                $errors += "MaxFileThreshold must be between 1 and 10000"
            }
            
            if ($perf.TimeoutSeconds -and ($perf.TimeoutSeconds -lt 1 -or $perf.TimeoutSeconds -gt 300)) {
                $errors += "TimeoutSeconds must be between 1 and 300"
            }
            
            if ($perf.MaxParallelJobs -and ($perf.MaxParallelJobs -lt 1 -or $perf.MaxParallelJobs -gt 16)) {
                $warnings += "MaxParallelJobs should typically be between 1 and 16"
            }
        }
        
        # Validate feature dependencies
        if ($Config.Features) {
            $features = $Config.Features
            
            if ($features.IntelligentStaging -and -not $features.BatchOperations) {
                $warnings += "IntelligentStaging works best with BatchOperations enabled"
            }
        }
        
        # Validate version
        if ($Config.Version -and $Config.Version -notmatch '^\d+\.\d+\.\d+') {
            $errors += "Version must be in semantic version format (x.y.z)"
        }
        
    }
    catch {
        $errors += "Configuration validation error: $($_.Exception.Message)"
    }
    
    return @{
        IsValid = ($errors.Count -eq 0)
        Errors = $errors
        Warnings = $warnings
    }
}

<#
.SYNOPSIS
    Resets GitZoom configuration to defaults
    
.DESCRIPTION
    Resets all configuration values to their defaults and saves the configuration.
    Useful for troubleshooting configuration issues.
    
.PARAMETER Path
    Path to the Git repository. Defaults to current directory.
    
.PARAMETER Force
    Force reset without confirmation prompt.
    
.EXAMPLE
    Reset-GitZoomConfig
    
.EXAMPLE
    Reset-GitZoomConfig -Force
#>
function Reset-GitZoomConfig {
    [CmdletBinding()]
    param(
        [string]$Path = (Get-Location),
        [switch]$Force
    )
    
    try {
        if (-not $Force) {
            $confirm = Read-Host "Reset GitZoom configuration to defaults? (y/N)"
            if ($confirm -ne 'y' -and $confirm -ne 'Y') {
                Write-Host "Configuration reset cancelled" -ForegroundColor Yellow
                return
            }
        }
        
        Push-Location $Path
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if (-not $gitRoot -or $LASTEXITCODE -ne 0) {
            throw "Not a valid Git repository"
        }
        
        $configFile = Join-Path $gitRoot ".gitzoom"
        $defaultConfig = Get-DefaultConfig
        $defaultConfig.Repository = $gitRoot
        $defaultConfig.InitializedAt = Get-Date
        
        # Save default configuration
        $defaultConfig | ConvertTo-Json -Depth 4 | Set-Content $configFile -Encoding UTF8
        
        Write-Host "✅ GitZoom configuration reset to defaults" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to reset GitZoom configuration: $($_.Exception.Message)"
        throw
    }
    finally {
        Pop-Location
    }
}

<#
.SYNOPSIS
    Shows the current GitZoom configuration in a readable format
    
.DESCRIPTION
    Displays the current configuration with syntax highlighting and validation status.
    Useful for debugging and reviewing configuration settings.
    
.PARAMETER Path
    Path to the Git repository. Defaults to current directory.
    
.PARAMETER ShowValidation
    Include configuration validation results.
    
.EXAMPLE
    Show-GitZoomConfig
    
.EXAMPLE
    Show-GitZoomConfig -ShowValidation
#>
function Show-GitZoomConfig {
    [CmdletBinding()]
    param(
        [string]$Path = (Get-Location),
        [switch]$ShowValidation
    )
    
    try {
        $config = Get-GitZoomConfig -Path $Path
        
        Write-Host ""
        Write-Host "⚙️ GitZoom Configuration" -ForegroundColor Blue
        Write-Host "=" * 50 -ForegroundColor DarkGray
        
        # Display configuration sections
        foreach ($section in $config.GetEnumerator() | Sort-Object Name) {
            if ($section.Value -is [hashtable] -or $section.Value.GetType().Name -eq "PSCustomObject") {
                Write-Host ""
                Write-Host "[$($section.Name)]" -ForegroundColor Cyan
                
                $sectionData = $section.Value
                if ($section.Value.GetType().Name -eq "PSCustomObject") {
                    $sectionData = @{}
                    $section.Value.PSObject.Properties | ForEach-Object {
                        $sectionData[$_.Name] = $_.Value
                    }
                }
                
                foreach ($setting in $sectionData.GetEnumerator() | Sort-Object Name) {
                    $value = $setting.Value
                    $color = switch ($value.GetType().Name) {
                        "Boolean" { if ($value) { "Green" } else { "Red" } }
                        "Int32" { "Yellow" }
                        "String" { "White" }
                        default { "Gray" }
                    }
                    Write-Host "  $($setting.Name) = $value" -ForegroundColor $color
                }
            }
            else {
                Write-Host "$($section.Name) = $($section.Value)" -ForegroundColor White
            }
        }
        
        if ($ShowValidation) {
            Write-Host ""
            $validation = Test-GitZoomConfig -Config $config
            
            if ($validation.IsValid) {
                Write-Host "✅ Configuration is valid" -ForegroundColor Green
            }
            else {
                Write-Host "❌ Configuration has errors:" -ForegroundColor Red
                $validation.Errors | ForEach-Object {
                    Write-Host "   • $_" -ForegroundColor Red
                }
            }
            
            if ($validation.Warnings.Count -gt 0) {
                Write-Host "⚠️ Configuration warnings:" -ForegroundColor Yellow
                $validation.Warnings | ForEach-Object {
                    Write-Host "   • $_" -ForegroundColor Yellow
                }
            }
        }
        
        Write-Host ""
    }
    catch {
        Write-Error "Failed to show GitZoom configuration: $($_.Exception.Message)"
    }
}

#endregion

# Export functions (handled by module manifest)
# Export-ModuleMember -Function @(
#     "Get-GitZoomConfig",
#     "Set-GitZoomConfig",
#     "Get-DefaultConfig",
#     "Test-GitZoomConfig", 
#     "Reset-GitZoomConfig",
#     "Show-GitZoomConfig"
# )