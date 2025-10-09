<#
.SYNOPSIS
    GitZoom Installation and Module Management System
    
.DESCRIPTION
    Provides installation, update, and module management capabilities for GitZoom
    with support for multiple installation methods and dependency management.
#>

#region Installation System

<#
.SYNOPSIS
    Installs GitZoom to the system
    
.DESCRIPTION
    Comprehensive installation function that sets up GitZoom modules, configuration,
    and integration with PowerShell profile for easy access.
    
.PARAMETER InstallPath
    Custom installation path (default: user modules directory)
    
.PARAMETER Scope
    Installation scope (CurrentUser, AllUsers)
    
.PARAMETER AddToProfile
    Add GitZoom to PowerShell profile for auto-loading
    
.PARAMETER CreateDesktopShortcut
    Create desktop shortcut for GitZoom commands
    
.PARAMETER Force
    Force installation even if already installed
    
.EXAMPLE
    Install-GitZoom -Scope CurrentUser -AddToProfile
    
.EXAMPLE
    Install-GitZoom -InstallPath "C:\Tools\GitZoom" -Force
#>
function Install-GitZoom {
    [CmdletBinding()]
    param(
        [string]$InstallPath,
        
        [ValidateSet("CurrentUser", "AllUsers")]
        [string]$Scope = "CurrentUser",
        
        [switch]$AddToProfile,
        
        [switch]$CreateDesktopShortcut,
        
        [switch]$Force
    )
    
    $installation = @{
        Success = $false
        InstallPath = $null
        Version = $null
        Errors = @()
        Warnings = @()
        Actions = @()
    }
    
    try {
        Write-Host "Installing GitZoom..." -ForegroundColor Green
        
        # Determine installation path
        if (-not $InstallPath) {
            if ($Scope -eq "AllUsers") {
                $InstallPath = Join-Path $env:ProgramFiles "PowerShell\Modules\GitZoom"
            }
            else {
                $modulesPath = $env:PSModulePath -split ';' | Where-Object { $_ -like "*$env:USERNAME*" } | Select-Object -First 1
                if (-not $modulesPath) {
                    $modulesPath = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "PowerShell\Modules"
                }
                $InstallPath = Join-Path $modulesPath "GitZoom"
            }
        }
        
        $installation.InstallPath = $InstallPath
        
        # Check if already installed
        if ((Test-Path $InstallPath) -and -not $Force) {
            $existing = Get-GitZoomVersion -Path $InstallPath
            if ($existing) {
                $installation.Warnings += "GitZoom is already installed at $InstallPath (version $existing). Use -Force to reinstall."
                return $installation
            }
        }
        
        # Validate prerequisites
        $prerequisites = Test-InstallationPrerequisites -Scope $Scope
        if (-not $prerequisites.Valid) {
            foreach ($prereqError in $prerequisites.Errors) {
                $installation.Errors += $prereqError
            }
            return $installation
        }
        
        # Create installation directory
        if (-not (Test-Path $InstallPath)) {
            New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
            $installation.Actions += "Created installation directory: $InstallPath"
        }
        
        # Copy GitZoom modules
        $copyResult = Copy-GitZoomModules -SourcePath (Get-Location) -DestinationPath $InstallPath -Force:$Force
        if (-not $copyResult.Success) {
            $installation.Errors += $copyResult.Errors
            return $installation
        }
        $installation.Actions += $copyResult.Actions
        
        # Create module manifest
        $manifestResult = New-GitZoomManifest -InstallPath $InstallPath
        if (-not $manifestResult.Success) {
            $installation.Errors += $manifestResult.Errors
            return $installation
        }
        $installation.Actions += "Created module manifest"
        $installation.Version = $manifestResult.Version
        
        # Configure GitZoom
        $configResult = Initialize-GitZoomConfiguration -InstallPath $InstallPath
        if ($configResult.Success) {
            $installation.Actions += "Initialized default configuration"
        }
        else {
            $installation.Warnings += "Configuration initialization had issues: $($configResult.Errors -join '; ')"
        }
        
        # Add to PowerShell profile if requested
        if ($AddToProfile) {
            $profileResult = Add-GitZoomToProfile -InstallPath $InstallPath
            if ($profileResult.Success) {
                $installation.Actions += "Added GitZoom to PowerShell profile"
            }
            else {
                $installation.Warnings += "Failed to add to profile: $($profileResult.Error)"
            }
        }
        
        # Create desktop shortcut if requested
        if ($CreateDesktopShortcut) {
            $shortcutResult = New-GitZoomShortcut -InstallPath $InstallPath
            if ($shortcutResult.Success) {
                $installation.Actions += "Created desktop shortcut"
            }
            else {
                $installation.Warnings += "Failed to create shortcut: $($shortcutResult.Error)"
            }
        }
        
        # Verify installation
        $verification = Test-GitZoomInstallation -InstallPath $InstallPath
        if ($verification.Valid) {
            $installation.Success = $true
            Write-Host "GitZoom installation completed successfully!" -ForegroundColor Green
            Write-Host "Installation path: $InstallPath" -ForegroundColor Cyan
            Write-Host "Version: $($installation.Version)" -ForegroundColor Cyan
            
            if ($AddToProfile) {
                Write-Host "GitZoom will be available in new PowerShell sessions." -ForegroundColor Yellow
                Write-Host "To use in current session, run: Import-Module '$InstallPath'" -ForegroundColor Yellow
            }
        }
        else {
            $installation.Errors += $verification.Errors
        }
        
        return $installation
    }
    catch {
        $installation.Errors += "Installation failed: $($_.Exception.Message)"
        Write-Error "GitZoom installation failed: $($_.Exception.Message)"
        return $installation
    }
}

<#
.SYNOPSIS
    Uninstalls GitZoom from the system
    
.DESCRIPTION
    Removes GitZoom modules, configuration, and profile entries with
    optional backup of user configuration and data.
    
.PARAMETER InstallPath
    Path to GitZoom installation (auto-detected if not provided)
    
.PARAMETER KeepConfiguration
    Preserve user configuration files
    
.PARAMETER KeepLogs
    Preserve log files
    
.PARAMETER RemoveFromProfile
    Remove GitZoom entries from PowerShell profile
    
.PARAMETER Force
    Force removal without confirmation
    
.EXAMPLE
    Uninstall-GitZoom -KeepConfiguration -RemoveFromProfile
    
.EXAMPLE
    Uninstall-GitZoom -InstallPath "C:\Tools\GitZoom" -Force
#>
function Uninstall-GitZoom {
    [CmdletBinding()]
    param(
        [string]$InstallPath,
        
        [switch]$KeepConfiguration,
        
        [switch]$KeepLogs,
        
        [switch]$RemoveFromProfile,
        
        [switch]$Force
    )
    
    $uninstallation = @{
        Success = $false
        RemovedPath = $null
        BackupPath = $null
        Errors = @()
        Warnings = @()
        Actions = @()
    }
    
    try {
        Write-Host "Uninstalling GitZoom..." -ForegroundColor Yellow
        
        # Find GitZoom installation if not provided
        if (-not $InstallPath) {
            $InstallPath = Find-GitZoomInstallation
            if (-not $InstallPath) {
                $uninstallation.Errors += "GitZoom installation not found"
                return $uninstallation
            }
        }
        
        if (-not (Test-Path $InstallPath)) {
            $uninstallation.Errors += "GitZoom installation path does not exist: $InstallPath"
            return $uninstallation
        }
        
        $uninstallation.RemovedPath = $InstallPath
        
        # Confirmation unless forced
        if (-not $Force) {
            $response = Read-Host "Are you sure you want to uninstall GitZoom from '$InstallPath'? (y/N)"
            if ($response -notmatch '^y(es)?$') {
                Write-Host "Uninstallation cancelled." -ForegroundColor Yellow
                return $uninstallation
            }
        }
        
        # Create backup if preserving data
        if ($KeepConfiguration -or $KeepLogs) {
            $backupResult = New-GitZoomBackup -InstallPath $InstallPath -IncludeConfig:$KeepConfiguration -IncludeLogs:$KeepLogs
            if ($backupResult.Success) {
                $uninstallation.BackupPath = $backupResult.BackupPath
                $uninstallation.Actions += "Created backup at: $($backupResult.BackupPath)"
            }
            else {
                $uninstallation.Warnings += "Backup creation failed: $($backupResult.Error)"
            }
        }
        
        # Stop any running GitZoom processes
        $processResult = Stop-GitZoomProcesses
        if ($processResult.StoppedCount -gt 0) {
            $uninstallation.Actions += "Stopped $($processResult.StoppedCount) GitZoom processes"
        }
        
        # Remove from PowerShell profile if requested
        if ($RemoveFromProfile) {
            $profileResult = Remove-GitZoomFromProfile
            if ($profileResult.Success) {
                $uninstallation.Actions += "Removed GitZoom from PowerShell profile"
            }
            else {
                $uninstallation.Warnings += "Failed to remove from profile: $($profileResult.Error)"
            }
        }
        
        # Remove desktop shortcuts
        $shortcutResult = Remove-GitZoomShortcuts
        if ($shortcutResult.RemovedCount -gt 0) {
            $uninstallation.Actions += "Removed $($shortcutResult.RemovedCount) shortcuts"
        }
        
        # Remove installation directory
        try {
            Remove-Item -Path $InstallPath -Recurse -Force
            $uninstallation.Actions += "Removed installation directory"
            $uninstallation.Success = $true
            
            Write-Host "GitZoom uninstalled successfully!" -ForegroundColor Green
            
            if ($uninstallation.BackupPath) {
                Write-Host "Backup created at: $($uninstallation.BackupPath)" -ForegroundColor Cyan
            }
        }
        catch {
            $uninstallation.Errors += "Failed to remove installation directory: $($_.Exception.Message)"
        }
        
        return $uninstallation
    }
    catch {
        $uninstallation.Errors += "Uninstallation failed: $($_.Exception.Message)"
        Write-Error "GitZoom uninstallation failed: $($_.Exception.Message)"
        return $uninstallation
    }
}

<#
.SYNOPSIS
    Updates GitZoom to the latest version
    
.DESCRIPTION
    Downloads and installs the latest version of GitZoom while preserving
    user configuration and data.
    
.PARAMETER Source
    Update source (GitHub, Local, Custom)
    
.PARAMETER Version
    Specific version to update to (default: latest)
    
.PARAMETER PreserveConfig
    Preserve existing configuration during update
    
.PARAMETER Force
    Force update even if already up to date
    
.EXAMPLE
    Update-GitZoom -Source GitHub -PreserveConfig
    
.EXAMPLE
    Update-GitZoom -Version "2.0.0" -Force
#>
function Update-GitZoom {
    [CmdletBinding()]
    param(
        [ValidateSet("GitHub", "Local", "Custom")]
        [string]$Source = "GitHub",
        
        [string]$Version,
        
        [switch]$PreserveConfig,
        
        [switch]$Force
    )
    
    $update = @{
        Success = $false
        OldVersion = $null
        NewVersion = $null
        InstallPath = $null
        Errors = @()
        Warnings = @()
        Actions = @()
    }
    
    try {
        Write-Host "Updating GitZoom..." -ForegroundColor Green
        
        # Find current installation
        $currentInstallation = Find-GitZoomInstallation
        if (-not $currentInstallation) {
            $update.Errors += "GitZoom is not currently installed. Use Install-GitZoom instead."
            return $update
        }
        
        $update.InstallPath = $currentInstallation
        $update.OldVersion = Get-GitZoomVersion -Path $currentInstallation
        
        # Get available versions
        $availableVersions = Get-AvailableGitZoomVersions -Source $Source
        if (-not $availableVersions -or $availableVersions.Count -eq 0) {
            $update.Errors += "No versions available from source: $Source"
            return $update
        }
        
        # Determine target version
        $targetVersion = if ($Version) { 
            $Version 
        } else { 
            $availableVersions | Sort-Object { [Version]$_ } -Descending | Select-Object -First 1 
        }
        
        if ($targetVersion -notin $availableVersions) {
            $update.Errors += "Version $targetVersion is not available from source: $Source"
            return $update
        }
        
        $update.NewVersion = $targetVersion
        
        # Check if update is needed
        if (-not $Force -and $update.OldVersion -eq $targetVersion) {
            Write-Host "GitZoom is already up to date (version $targetVersion)" -ForegroundColor Yellow
            $update.Success = $true
            return $update
        }
        
        # Backup current installation if preserving config
        if ($PreserveConfig) {
            $backupResult = New-GitZoomBackup -InstallPath $currentInstallation -IncludeConfig
            if ($backupResult.Success) {
                $update.Actions += "Created configuration backup"
            }
            else {
                $update.Warnings += "Configuration backup failed: $($backupResult.Error)"
            }
        }
        
        # Download/prepare new version
        $downloadResult = Get-GitZoomVersion -Source $Source -Version $targetVersion -DownloadPath $env:TEMP
        if (-not $downloadResult.Success) {
            $update.Errors += $downloadResult.Errors
            return $update
        }
        
        # Stop GitZoom processes
        $processResult = Stop-GitZoomProcesses
        if ($processResult.StoppedCount -gt 0) {
            $update.Actions += "Stopped $($processResult.StoppedCount) GitZoom processes"
        }
        
        # Install new version
        $installResult = Install-GitZoom -InstallPath $currentInstallation -Force
        if (-not $installResult.Success) {
            $update.Errors += $installResult.Errors
            return $update
        }
        
        $update.Actions += $installResult.Actions
        
        # Restore configuration if preserved
        if ($PreserveConfig -and $backupResult.Success) {
            $restoreResult = Restore-GitZoomConfiguration -BackupPath $backupResult.BackupPath -InstallPath $currentInstallation
            if ($restoreResult.Success) {
                $update.Actions += "Restored configuration from backup"
            }
            else {
                $update.Warnings += "Configuration restore failed: $($restoreResult.Error)"
            }
        }
        
        # Verify update
        $newVersionInstalled = Get-GitZoomVersion -Path $currentInstallation
        if ($newVersionInstalled -eq $targetVersion) {
            $update.Success = $true
            Write-Host "GitZoom updated successfully!" -ForegroundColor Green
            Write-Host "Old version: $($update.OldVersion)" -ForegroundColor Cyan
            Write-Host "New version: $($update.NewVersion)" -ForegroundColor Cyan
        }
        else {
            $update.Errors += "Update verification failed. Expected version $targetVersion, but found $newVersionInstalled"
        }
        
        return $update
    }
    catch {
        $update.Errors += "Update failed: $($_.Exception.Message)"
        Write-Error "GitZoom update failed: $($_.Exception.Message)"
        return $update
    }
}

<#
.SYNOPSIS
    Gets information about GitZoom installation
    
.DESCRIPTION
    Retrieves comprehensive information about the current GitZoom installation
    including version, path, configuration, and health status.
    
.PARAMETER Detailed
    Include detailed diagnostic information
    
.EXAMPLE
    Get-GitZoomInstallation -Detailed
#>
function Get-GitZoomInstallation {
    [CmdletBinding()]
    param(
        [switch]$Detailed
    )
    
    $info = @{
        IsInstalled = $false
        InstallPath = $null
        Version = $null
        Scope = $null
        Configuration = @{}
        Health = @{}
        Details = @{}
    }
    
    try {
        # Find installation
        $installPath = Find-GitZoomInstallation
        if (-not $installPath) {
            Write-Host "GitZoom is not installed" -ForegroundColor Yellow
            return $info
        }
        
        $info.IsInstalled = $true
        $info.InstallPath = $installPath
        
        # Get version
        $info.Version = Get-GitZoomVersion -Path $installPath
        
        # Determine scope
        if ($installPath -like "*Program Files*") {
            $info.Scope = "AllUsers"
        }
        else {
            $info.Scope = "CurrentUser"
        }
        
        # Get configuration info
        try {
            $config = Get-GitZoomConfig
            $info.Configuration = @{
                Exists = $true
                Location = $config.ConfigPath
                LastModified = if (Test-Path $config.ConfigPath) { (Get-Item $config.ConfigPath).LastWriteTime } else { $null }
            }
        }
        catch {
            $info.Configuration = @{
                Exists = $false
                Error = $_.Exception.Message
            }
        }
        
        # Health check
        if ($Detailed) {
            $healthCheck = Test-GitZoomInstallation -InstallPath $installPath
            $info.Health = $healthCheck
            
            # Additional details
            $info.Details = @{
                ModuleFiles = Get-ChildItem -Path $installPath -Filter "*.ps1" -Recurse | Measure-Object | Select-Object -ExpandProperty Count
                TotalSize = [math]::Round((Get-ChildItem -Path $installPath -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
                LastAccessed = (Get-ChildItem -Path $installPath -Recurse | Sort-Object LastAccessTime -Descending | Select-Object -First 1).LastAccessTime
                InProfile = Test-GitZoomInProfile
                Dependencies = Test-GitZoomDependencies
            }
        }
        
        # Display information
        Write-Host "GitZoom Installation Information" -ForegroundColor Green
        Write-Host "================================" -ForegroundColor Green
        Write-Host "Installed: $($info.IsInstalled)" -ForegroundColor Cyan
        Write-Host "Version: $($info.Version)" -ForegroundColor Cyan
        Write-Host "Path: $($info.InstallPath)" -ForegroundColor Cyan
        Write-Host "Scope: $($info.Scope)" -ForegroundColor Cyan
        
        if ($info.Configuration.Exists) {
            Write-Host "Configuration: Available" -ForegroundColor Green
        }
        else {
            Write-Host "Configuration: Missing" -ForegroundColor Yellow
        }
        
        if ($Detailed -and $info.Details) {
            Write-Host "`nDetailed Information:" -ForegroundColor Green
            Write-Host "Module Files: $($info.Details.ModuleFiles)" -ForegroundColor Cyan
            Write-Host "Total Size: $($info.Details.TotalSize) MB" -ForegroundColor Cyan
            Write-Host "In Profile: $($info.Details.InProfile)" -ForegroundColor Cyan
        }
        
        return $info
    }
    catch {
        Write-Error "Failed to get installation information: $($_.Exception.Message)"
        return $info
    }
}

#endregion

#region Helper Functions

<#
.SYNOPSIS
    Finds GitZoom installation path
#>
function Find-GitZoomInstallation {
    # Check common installation paths
    $possiblePaths = @(
        # User modules
        (Join-Path ([Environment]::GetFolderPath("MyDocuments")) "PowerShell\Modules\GitZoom"),
        (Join-Path ([Environment]::GetFolderPath("MyDocuments")) "WindowsPowerShell\Modules\GitZoom"),
        # System modules
        (Join-Path $env:ProgramFiles "PowerShell\Modules\GitZoom"),
        (Join-Path $env:ProgramFiles "WindowsPowerShell\Modules\GitZoom")
    )
    
    # Also check PSModulePath
    $env:PSModulePath -split ';' | ForEach-Object {
        $possiblePaths += Join-Path $_ "GitZoom"
    }
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $manifestPath = Join-Path $path "GitZoom.psd1"
            if (Test-Path $manifestPath) {
                return $path
            }
        }
    }
    
    return $null
}

<#
.SYNOPSIS
    Gets GitZoom version from installation path
#>
function Get-GitZoomVersion {
    param(
        [string]$Path
    )
    
    try {
        $manifestPath = Join-Path $Path "GitZoom.psd1"
        if (Test-Path $manifestPath) {
            $manifest = Import-PowerShellDataFile $manifestPath
            return $manifest.ModuleVersion
        }
    }
    catch {
        # Fallback: check for version in module file
        $moduleFile = Join-Path $Path "GitZoom.psm1"
        if (Test-Path $moduleFile) {
            $content = Get-Content $moduleFile -Raw
            if ($content -match "Version\s*=\s*[`'`"](.+?)[`'`"]") {
                return $matches[1]
            }
        }
    }
    
    return "Unknown"
}

<#
.SYNOPSIS
    Tests installation prerequisites
#>
function Test-InstallationPrerequisites {
    param(
        [string]$Scope
    )
    
    $result = @{
        Valid = $true
        Errors = @()
        Warnings = @()
    }
    
    # Test PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $result.Valid = $false
        $result.Errors += "PowerShell 5.0 or higher is required"
    }
    
    # Test Git installation
    try {
        git --version | Out-Null
        if ($LASTEXITCODE -ne 0) {
            $result.Valid = $false
            $result.Errors += "Git is not installed or not accessible"
        }
    }
    catch {
        $result.Valid = $false
        $result.Errors += "Git is not installed or not accessible"
    }
    
    # Test permissions for scope
    if ($Scope -eq "AllUsers") {
        $testPath = Join-Path $env:ProgramFiles "PowerShell\Modules"
        try {
            $testFile = Join-Path $testPath "gitzoom-test-$(Get-Random).tmp"
            "test" | Out-File $testFile -ErrorAction Stop
            Remove-Item $testFile -ErrorAction SilentlyContinue
        }
        catch {
            $result.Valid = $false
            $result.Errors += "Insufficient permissions for AllUsers installation. Run as Administrator or use CurrentUser scope."
        }
    }
    
    return $result
}

#endregion

# Export functions
Export-ModuleMember -Function @(
    "Install-GitZoom",
    "Uninstall-GitZoom", 
    "Update-GitZoom",
    "Get-GitZoomInstallation"
)