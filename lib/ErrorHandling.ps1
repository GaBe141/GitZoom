<#
.SYNOPSIS
    GitZoom Error Handling and Recovery Framework
    
.DESCRIPTION
    Provides comprehensive error handling, recovery mechanisms, and resilient
    operations for all GitZoom components with detailed logging and diagnostics.
#>

#region Error Handling Framework

<#
.SYNOPSIS
    Initializes the GitZoom error handling system
    
.DESCRIPTION
    Sets up error handling, logging, and recovery mechanisms for the current session.
    
.PARAMETER LogLevel
    Logging level (Error, Warning, Information, Verbose)
    
.PARAMETER LogPath
    Custom path for log files
    
.PARAMETER EnableRecovery
    Enable automatic recovery mechanisms
    
.EXAMPLE
    Initialize-ErrorHandling -LogLevel "Information" -EnableRecovery
#>
function Initialize-ErrorHandling {
    [CmdletBinding()]
    param(
        [ValidateSet("Error", "Warning", "Information", "Verbose")]
        [string]$LogLevel = "Information",
        
        [string]$LogPath,
        
        [switch]$EnableRecovery
    )
    
    try {
        # Set up global error handling variables
        $global:GitZoomErrorContext = @{
            LogLevel = $LogLevel
            LogPath = if ($LogPath) { $LogPath } else { Join-Path $env:TEMP "GitZoom" }
            EnableRecovery = $EnableRecovery.IsPresent
            SessionId = [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
            StartTime = Get-Date
            ErrorCount = 0
            WarningCount = 0
            RecoveryCount = 0
        }
        
        # Ensure log directory exists
        if (-not (Test-Path $global:GitZoomErrorContext.LogPath)) {
            New-Item -Path $global:GitZoomErrorContext.LogPath -ItemType Directory -Force | Out-Null
        }
        
        # Set up error action preference
        $global:GitZoomOriginalErrorActionPreference = $ErrorActionPreference
        
        Write-GitZoomLog -Level "Information" -Message "GitZoom error handling initialized (Session: $($global:GitZoomErrorContext.SessionId))"
        
        return $true
    }
    catch {
        Write-Error "Failed to initialize error handling: $($_.Exception.Message)"
        return $false
    }
}

<#
.SYNOPSIS
    Wraps operations with comprehensive error handling
    
.DESCRIPTION
    Provides a safe execution wrapper that handles errors, attempts recovery,
    and maintains detailed logs of all operations and failures.
    
.PARAMETER ScriptBlock
    The operation to execute safely
    
.PARAMETER Operation
    Name of the operation for logging
    
.PARAMETER AllowRecovery
    Whether recovery should be attempted on failure
    
.PARAMETER RetryCount
    Number of retry attempts (default: 2)
    
.PARAMETER Context
    Additional context information for error handling
    
.EXAMPLE
    Invoke-SafeOperation -ScriptBlock { git status } -Operation "StatusCheck"
    
.EXAMPLE
    Invoke-SafeOperation -ScriptBlock { $code } -Operation "FileStaging" -AllowRecovery -RetryCount 3
#>
function Invoke-SafeOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ScriptBlock]$ScriptBlock,
        
        [Parameter(Mandatory)]
        [string]$Operation,
        
        [switch]$AllowRecovery,
        
        [int]$RetryCount = 2,
        
        [hashtable]$Context = @{}
    )
    
    $result = @{
        Success = $false
        Result = $null
        Error = $null
        Warnings = @()
        Attempts = 0
        RecoveryApplied = $false
        Duration = 0
    }
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        Write-GitZoomLog -Level "Verbose" -Message "Starting operation: $Operation"
        
        $attempt = 0
        $maxAttempts = $RetryCount + 1
        
        while ($attempt -lt $maxAttempts) {
            $attempt++
            $result.Attempts = $attempt
            
            try {
                Write-GitZoomLog -Level "Verbose" -Message "Operation '$Operation' attempt $attempt of $maxAttempts"
                
                # Execute the operation
                $operationResult = & $ScriptBlock
                
                # Success
                $result.Success = $true
                $result.Result = $operationResult
                
                Write-GitZoomLog -Level "Information" -Message "Operation '$Operation' completed successfully on attempt $attempt"
                break
            }
            catch {
                $lastError = $_
                $result.Error = $lastError.Exception.Message
                
                Write-GitZoomLog -Level "Error" -Message "Operation '$Operation' failed on attempt $attempt`: $($lastError.Exception.Message)" -Exception $lastError.Exception
                
                # Increment global error count
                if ($global:GitZoomErrorContext) {
                    $global:GitZoomErrorContext.ErrorCount++
                }
                
                # Check if we should retry
                if ($attempt -lt $maxAttempts) {
                    # Attempt recovery if enabled
                    if ($AllowRecovery -and $global:GitZoomErrorContext.EnableRecovery) {
                        Write-GitZoomLog -Level "Information" -Message "Attempting recovery for operation '$Operation'"
                        
                        $recoveryResult = Invoke-ErrorRecovery -Operation $Operation -ErrorRecord $lastError -Context $Context
                        
                        if ($recoveryResult.Applied) {
                            $result.RecoveryApplied = $true
                            Write-GitZoomLog -Level "Information" -Message "Recovery applied: $($recoveryResult.Description)"
                        }
                    }
                    
                    # Wait before retry
                    $waitTime = [Math]::Min(1000 * $attempt, 5000)  # Max 5 second wait
                    Write-GitZoomLog -Level "Verbose" -Message "Waiting $waitTime ms before retry..."
                    Start-Sleep -Milliseconds $waitTime
                }
                else {
                    # Final failure
                    Write-GitZoomLog -Level "Error" -Message "Operation '$Operation' failed after $maxAttempts attempts"
                    break
                }
            }
        }
        
    }
    catch {
        # Catastrophic failure in the wrapper itself
        $result.Error = "Critical error in operation wrapper: $($_.Exception.Message)"
        Write-GitZoomLog -Level "Error" -Message $result.Error -Exception $_.Exception
    }
    finally {
        $stopwatch.Stop()
        $result.Duration = $stopwatch.ElapsedMilliseconds
        
        Write-GitZoomLog -Level "Verbose" -Message "Operation '$Operation' completed in $($result.Duration)ms (Success: $($result.Success))"
    }
    
    return $result
}

<#
.SYNOPSIS
    Attempts automatic recovery from common Git operation failures
    
.DESCRIPTION
    Analyzes errors and applies appropriate recovery strategies such as
    repository cleanup, index repair, or configuration fixes.
    
.PARAMETER Operation
    The operation that failed
    
.PARAMETER ErrorRecord
    The error that occurred
    
.PARAMETER Context
    Additional context for recovery decisions
    
.EXAMPLE
    Invoke-ErrorRecovery -Operation "StatusCheck" -ErrorRecord $errorRecord
#>
function Invoke-ErrorRecovery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Operation,
        
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        
        [hashtable]$Context = @{}
    )
    
    $recovery = @{
        Applied = $false
        Description = "No recovery attempted"
        Actions = @()
    }
    
    try {
        $errorMessage = $ErrorRecord.Exception.Message.ToLower()
        Write-GitZoomLog -Level "Verbose" -Message "Analyzing error for recovery (Operation: $Operation): $errorMessage"
        
        # Repository corruption recovery
        if ($errorMessage -match "index.*corrupt|bad.*index|broken.*index") {
            $recovery = Repair-GitIndex
        }
        # Lock file recovery
        elseif ($errorMessage -match "lock.*file|\.lock") {
            $recovery = Remove-GitLockFiles
        }
        # Permission issues
        elseif ($errorMessage -match "permission.*denied|access.*denied") {
            $recovery = Repair-GitPermissions
        }
        # Network connectivity issues
        elseif ($errorMessage -match "network|connection|timeout|unreachable") {
            $recovery = Repair-NetworkConnectivity -Context $Context
        }
        # Repository state issues
        elseif ($errorMessage -match "not.*repository|fatal.*repository") {
            $recovery = Repair-RepositoryState
        }
        # Configuration issues
        elseif ($errorMessage -match "config|configuration") {
            $recovery = Repair-GitConfiguration
        }
        # Disk space issues
        elseif ($errorMessage -match "space|disk.*full|no.*space") {
            $recovery = Handle-DiskSpaceIssue
        }
        else {
            Write-GitZoomLog -Level "Verbose" -Message "No automatic recovery available for this error type"
        }
        
        if ($recovery.Applied) {
            if ($global:GitZoomErrorContext) {
                $global:GitZoomErrorContext.RecoveryCount++
            }
        }
        
        return $recovery
    }
    catch {
        Write-GitZoomLog -Level "Error" -Message "Recovery attempt failed: $($_.Exception.Message)"
        return $recovery
    }
}

<#
.SYNOPSIS
    Writes structured log entries to the GitZoom log system
    
.DESCRIPTION
    Provides centralized logging with multiple levels, structured format,
    and optional exception details for comprehensive diagnostics.
    
.PARAMETER Level
    Log level (Error, Warning, Information, Verbose)
    
.PARAMETER Message
    Log message
    
.PARAMETER Exception
    Optional exception object for detailed logging
    
.PARAMETER Context
    Additional context data
    
.EXAMPLE
    Write-GitZoomLog -Level "Error" -Message "Operation failed" -Exception $_.Exception
#>
function Write-GitZoomLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Error", "Warning", "Information", "Verbose")]
        [string]$Level,
        
        [Parameter(Mandatory)]
        [string]$Message,
        
        [System.Exception]$Exception,
        
        [hashtable]$Context = @{}
    )
    
    try {
        # Check if logging is initialized
        if (-not $global:GitZoomErrorContext) {
            return
        }
        
        # Check log level filtering
        $levelOrder = @{ "Error" = 0; "Warning" = 1; "Information" = 2; "Verbose" = 3 }
        $currentLevelOrder = $levelOrder[$global:GitZoomErrorContext.LogLevel]
        $messageLevelOrder = $levelOrder[$Level]
        
        if ($messageLevelOrder -gt $currentLevelOrder) {
            return
        }
        
        # Create log entry
        $logEntry = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
            SessionId = $global:GitZoomErrorContext.SessionId
            Level = $Level
            Message = $Message
            ProcessId = $PID
            Thread = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        }
        
        # Add exception details if provided
        if ($Exception) {
            $logEntry.Exception = @{
                Type = $Exception.GetType().FullName
                Message = $Exception.Message
                StackTrace = $Exception.StackTrace
                InnerException = if ($Exception.InnerException) { $Exception.InnerException.Message } else { $null }
            }
        }
        
        # Add context if provided
        if ($Context.Count -gt 0) {
            $logEntry.Context = $Context
        }
        
        # Format log entry
        $logLine = "[$($logEntry.Timestamp)] [$($logEntry.Level.ToUpper())] [$($logEntry.SessionId)] $($logEntry.Message)"
        
        if ($Exception) {
            $logLine += "`n  Exception: $($Exception.GetType().Name) - $($Exception.Message)"
            if ($Exception.StackTrace) {
                $logLine += "`n  StackTrace: $($Exception.StackTrace)"
            }
        }
        
        # Write to console based on level
        switch ($Level) {
            "Error" {
                Write-Error $logLine
            }
            "Warning" {
                Write-Warning $Message
            }
            "Information" {
                Write-Information $Message -InformationAction Continue
            }
            "Verbose" {
                Write-Verbose $Message
            }
        }
        
        # Write to log file
        $logFile = Join-Path $global:GitZoomErrorContext.LogPath "gitzoom-$($global:GitZoomErrorContext.SessionId).log"
        $logLine | Add-Content -Path $logFile -Encoding UTF8
        
        # Also write as JSON for structured analysis
        $jsonFile = Join-Path $global:GitZoomErrorContext.LogPath "gitzoom-$($global:GitZoomErrorContext.SessionId).json"
        $logEntry | ConvertTo-Json -Compress | Add-Content -Path $jsonFile -Encoding UTF8
        
    }
    catch {
        # Fallback logging if our logging system fails
        Write-Error "GitZoom logging failed: $($_.Exception.Message). Original message: $Message"
    }
}

<#
.SYNOPSIS
    Validates the current GitZoom environment and dependencies
    
.DESCRIPTION
    Performs comprehensive validation of the Git installation, repository state,
    permissions, and GitZoom configuration to identify potential issues.
    
.EXAMPLE
    Test-GitZoomEnvironment
#>
function Test-GitZoomEnvironment {
    [CmdletBinding()]
    param()
    
    $validation = @{
        IsValid = $true
        Errors = @()
        Warnings = @()
        Information = @()
        Tests = @()
    }
    
    try {
        Write-GitZoomLog -Level "Information" -Message "Starting GitZoom environment validation"
        
        # Test 1: Git Installation
        $gitTest = Test-GitInstallation
        $validation.Tests += $gitTest
        if (-not $gitTest.Success) {
            $validation.IsValid = $false
            $validation.Errors += $gitTest.Message
        }
        
        # Test 2: Repository State
        $repoTest = Test-RepositoryHealth
        $validation.Tests += $repoTest
        if (-not $repoTest.Success) {
            $validation.Warnings += $repoTest.Message
        }
        
        # Test 3: Permissions
        $permTest = Test-GitPermissions
        $validation.Tests += $permTest
        if (-not $permTest.Success) {
            $validation.Warnings += $permTest.Message
        }
        
        # Test 4: Disk Space
        $diskTest = Test-DiskSpace
        $validation.Tests += $diskTest
        if (-not $diskTest.Success) {
            $validation.Warnings += $diskTest.Message
        }
        
        # Test 5: GitZoom Configuration
        $configTest = Test-GitZoomConfigurationHealth
        $validation.Tests += $configTest
        if (-not $configTest.Success) {
            $validation.Warnings += $configTest.Message
        }
        
        # Test 6: Network Connectivity (if remotes exist)
        $networkTest = Test-GitNetworkConnectivity
        $validation.Tests += $networkTest
        if (-not $networkTest.Success) {
            $validation.Information += $networkTest.Message
        }
        
        # Summary
        $passedTests = ($validation.Tests | Where-Object { $_.Success }).Count
        $totalTests = $validation.Tests.Count
        
        Write-GitZoomLog -Level "Information" -Message "Environment validation complete: $passedTests/$totalTests tests passed"
        
        return $validation
    }
    catch {
        $validation.IsValid = $false
        $validation.Errors += "Environment validation failed: $($_.Exception.Message)"
        Write-GitZoomLog -Level "Error" -Message "Environment validation crashed" -Exception $_.Exception
        return $validation
    }
}

#endregion

#region Recovery Functions

<#
.SYNOPSIS
    Repairs corrupted Git index files
#>
function Repair-GitIndex {
    $recovery = @{ Applied = $false; Description = ""; Actions = @() }
    
    try {
        Write-GitZoomLog -Level "Information" -Message "Attempting Git index repair"
        
        # Backup current index
        $backupPath = ".git/index.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        if (Test-Path ".git/index") {
            Copy-Item ".git/index" $backupPath -ErrorAction SilentlyContinue
            $recovery.Actions += "Backed up index to $backupPath"
        }
        
        # Remove corrupted index
        Remove-Item ".git/index" -Force -ErrorAction SilentlyContinue
        $recovery.Actions += "Removed corrupted index"
        
        # Rebuild index from HEAD
        $output = git read-tree HEAD 2>&1
        if ($LASTEXITCODE -eq 0) {
            $recovery.Applied = $true
            $recovery.Description = "Git index repaired successfully"
            $recovery.Actions += "Rebuilt index from HEAD"
        }
        else {
            $recovery.Description = "Index repair failed: $output"
        }
    }
    catch {
        $recovery.Description = "Index repair exception: $($_.Exception.Message)"
    }
    
    return $recovery
}

<#
.SYNOPSIS
    Removes Git lock files that prevent operations
#>
function Remove-GitLockFiles {
    $recovery = @{ Applied = $false; Description = ""; Actions = @() }
    
    try {
        Write-GitZoomLog -Level "Information" -Message "Removing Git lock files"
        
        $lockFiles = @(
            ".git/index.lock",
            ".git/refs/heads/*.lock",
            ".git/config.lock",
            ".git/HEAD.lock"
        )
        
        $removedCount = 0
        foreach ($lockPattern in $lockFiles) {
            $files = Get-ChildItem -Path $lockPattern -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
                $recovery.Actions += "Removed lock file: $($file.Name)"
                $removedCount++
            }
        }
        
        if ($removedCount -gt 0) {
            $recovery.Applied = $true
            $recovery.Description = "Removed $removedCount lock files"
        }
        else {
            $recovery.Description = "No lock files found to remove"
        }
    }
    catch {
        $recovery.Description = "Lock file removal failed: $($_.Exception.Message)"
    }
    
    return $recovery
}

#endregion

#region Validation Functions

<#
.SYNOPSIS
    Tests Git installation and version
#>
function Test-GitInstallation {
    $test = @{ Name = "Git Installation"; Success = $false; Message = ""; Details = @{} }
    
    try {
        $gitVersion = git --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $gitVersion) {
            $test.Success = $true
            $test.Message = "Git is installed: $gitVersion"
            $test.Details.Version = $gitVersion
        }
        else {
            $test.Message = "Git is not installed or not accessible in PATH"
        }
    }
    catch {
        $test.Message = "Git installation test failed: $($_.Exception.Message)"
    }
    
    return $test
}

<#
.SYNOPSIS
    Tests repository health and state
#>
function Test-RepositoryHealth {
    $test = @{ Name = "Repository Health"; Success = $false; Message = ""; Details = @{} }
    
    try {
        # Check if we're in a git repository
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -ne 0) {
            $test.Message = "Not in a Git repository"
            return $test
        }
        
        # Check repository integrity
        $fsckOutput = git fsck --no-progress 2>&1
        if ($LASTEXITCODE -eq 0) {
            $test.Success = $true
            $test.Message = "Repository integrity check passed"
        }
        else {
            $test.Message = "Repository has integrity issues: $fsckOutput"
        }
        
        $test.Details.GitRoot = $gitRoot
    }
    catch {
        $test.Message = "Repository health test failed: $($_.Exception.Message)"
    }
    
    return $test
}

#endregion

# Export functions
Export-ModuleMember -Function @(
    "Initialize-ErrorHandling",
    "Invoke-SafeOperation", 
    "Invoke-ErrorRecovery",
    "Write-GitZoomLog",
    "Test-GitZoomEnvironment"
)