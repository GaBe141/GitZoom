# GitZoom Security Fixes - Priority Implementation Guide

**Status:** CRITICAL - Implement Immediately
**Date:** 2024
**Risk Level:** HIGH

---

## 🔴 CRITICAL: Fix These First (Week 1)

### Fix #1: Command Injection Prevention

**File:** `lib/Staging.ps1`, `lib/Commit.ps1`, `lib/Performance.ps1`
**Lines:** Multiple locations where Git commands are executed
**Severity:** CRITICAL

#### Current Vulnerable Code:
```powershell
# lib/Staging.ps1 - Line ~85
$gitArgs = @("add")
if ($Force) { $gitArgs += "--force" }
$gitArgs += $Files  # VULNERABLE: User input directly passed

# lib/Commit.ps1 - Line ~450
$gitArgs = @("commit", "-m", $Message)  # VULNERABLE: Message not sanitized
$output = & git @gitArgs
```

#### Secure Implementation:
```powershell
# Add to lib/Utilities.ps1
function Invoke-SafeGitCommand {
    <#
    .SYNOPSIS
        Safely executes Git commands with input validation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('add', 'commit', 'push', 'pull', 'status', 'diff', 'log', 'branch', 'checkout', 'reset', 'rev-parse', 'config', 'show')]
        [string]$Command,
        
        [Parameter(Mandatory)]
        [string[]]$Arguments,
        
        [switch]$AllowUserPaths
    )
    
    # Validate command is in whitelist
    $allowedCommands = @('add', 'commit', 'push', 'pull', 'status', 'diff', 'log', 'branch', 'checkout', 'reset', 'rev-parse', 'config', 'show')
    if ($Command -notin $allowedCommands) {
        throw "Git command not allowed: $Command"
    }
    
    # Sanitize arguments
    $sanitizedArgs = @()
    foreach ($arg in $Arguments) {
        # Check for dangerous patterns
        if ($arg -match '[;&|`$<>]|^\-\-exec|^\-\-upload\-pack') {
            throw "Dangerous characters or options detected in argument: $arg"
        }
        
        # If it's a file path and user paths are allowed, validate it
        if ($AllowUserPaths -and -not ($arg -match '^-')) {
            $gitRoot = git rev-parse --show-toplevel 2>$null
            if ($gitRoot) {
                $fullPath = Join-Path (Get-Location) $arg
                $resolvedPath = [System.IO.Path]::GetFullPath($fullPath)
                $resolvedRoot = [System.IO.Path]::GetFullPath($gitRoot)
                
                if (-not $resolvedPath.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) {
                    throw "Path is outside repository: $arg"
                }
            }
        }
        
        $sanitizedArgs += $arg
    }
    
    # Execute safely using Start-Process
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "git"
    $psi.Arguments = "$Command $($sanitizedArgs -join ' ')"
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    [void]$process.Start()
    
    $output = $process.StandardOutput.ReadToEnd()
    $error = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    
    return @{
        Output = $output
        Error = $error
        ExitCode = $process.ExitCode
        Success = ($process.ExitCode -eq 0)
    }
}

# Update lib/Staging.ps1
function Invoke-SingleBatchStaging {
    param([string[]]$Files, [switch]$Force)
    
    $args = @()
    if ($Force) { $args += "--force" }
    $args += $Files
    
    # Use safe command execution
    $result = Invoke-SafeGitCommand -Command "add" -Arguments $args -AllowUserPaths
    
    if ($result.Success) {
        return @{ AddedFiles = $Files; Errors = @() }
    }
    else {
        return @{ AddedFiles = @(); Errors = @($result.Error) }
    }
}

# Update lib/Commit.ps1
function Invoke-GitCommit {
    param([string]$Message, [switch]$Amend, [switch]$AllowEmpty)
    
    # Validate message first
    if (-not (Test-CommitMessageSafety -Message $Message)) {
        throw "Commit message contains dangerous characters"
    }
    
    $args = @("-m", $Message)
    if ($Amend) { $args += "--amend" }
    if ($AllowEmpty) { $args += "--allow-empty" }
    
    # Use safe command execution
    $result = Invoke-SafeGitCommand -Command "commit" -Arguments $args
    
    return @{
        Success = $result.Success
        Hash = if ($result.Success) { git rev-parse HEAD } else { $null }
        Error = $result.Error
    }
}
```

---

### Fix #2: Commit Message Validation

**File:** `lib/Commit.ps1`
**Severity:** CRITICAL

#### Add to lib/Utilities.ps1:
```powershell
function Test-CommitMessageSafety {
    <#
    .SYNOPSIS
        Validates commit message for security issues
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )
    
    # Check for null or empty
    if ([string]::IsNullOrWhiteSpace($Message)) {
        throw "Commit message cannot be empty"
    }
    
    # Check length
    if ($Message.Length -gt 10000) {
        throw "Commit message too long (max 10000 characters)"
    }
    
    # Check for dangerous patterns
    $dangerousPatterns = @{
        'Control Characters' = '[\x00-\x08\x0B\x0C\x0E-\x1F]'
        'Backticks' = '`'
        'Command Substitution' = '\$\('
        'Command Separator' = ';'
        'Pipe' = '\|'
        'Background Execution' = '&'
        'Input Redirection' = '<'
        'Output Redirection' = '>'
        'Null Byte' = '\x00'
    }
    
    foreach ($patternName in $dangerousPatterns.Keys) {
        if ($Message -match $dangerousPatterns[$patternName]) {
            throw "Commit message contains dangerous pattern: $patternName"
        }
    }
    
    # Check for script injection attempts
    if ($Message -match '(powershell|cmd|bash|sh|python|perl|ruby)\s+(-c|-Command|-EncodedCommand)') {
        throw "Commit message contains potential script injection"
    }
    
    return $true
}
```

---

### Fix #3: Path Traversal Prevention

**File:** `lib/Staging.ps1`, `lib/Utilities.ps1`
**Severity:** CRITICAL

#### Add to lib/Utilities.ps1:
```powershell
function Test-PathWithinRepository {
    <#
    .SYNOPSIS
        Validates that a path is within the Git repository
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [string]$RepositoryRoot
    )
    
    if (-not $RepositoryRoot) {
        $RepositoryRoot = git rev-parse --show-toplevel 2>$null
        if (-not $RepositoryRoot -or $LASTEXITCODE -ne 0) {
            throw "Not in a Git repository"
        }
    }
    
    try {
        # Resolve to absolute paths
        $resolvedPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
        $resolvedRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
        
        # Check if path is within repository
        $isWithin = $resolvedPath.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)
        
        if (-not $isWithin) {
            throw "Path is outside repository: $Path"
        }
        
        # Additional checks for suspicious patterns
        if ($Path -match '\.\.[/\\]' -or $Path -match '^[/\\]') {
            throw "Path contains suspicious patterns: $Path"
        }
        
        return $true
    }
    catch {
        Write-Error "Path validation failed: $_"
        return $false
    }
}

# Update lib/Staging.ps1
function Get-FilesFromPatterns {
    param([string[]]$Patterns)
    
    $files = @()
    $gitRoot = Get-GitRepositoryRoot
    
    foreach ($pattern in $Patterns) {
        # Validate path before processing
        if (-not (Test-PathWithinRepository -Path $pattern -RepositoryRoot $gitRoot)) {
            Write-Warning "Skipping path outside repository: $pattern"
            continue
        }
        
        # Rest of existing logic...
    }
    
    return $files
}
```

---

### Fix #4: Secure Configuration Storage

**File:** `lib/Configuration.ps1`
**Severity:** CRITICAL

#### Implementation:
```powershell
function Protect-SensitiveConfiguration {
    <#
    .SYNOPSIS
        Encrypts sensitive configuration values using Windows DPAPI
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )
    
    $sensitiveKeys = @(
        'Password', 'ApiKey', 'Token', 'Secret', 'AccessToken',
        'PrivateKey', 'ConnectionString', 'Credential'
    )
    
    function Protect-Value {
        param([string]$Value)
        
        if ([string]::IsNullOrEmpty($Value)) {
            return $Value
        }
        
        try {
            # Use Windows DPAPI for encryption
            $secureString = ConvertTo-SecureString $Value -AsPlainText -Force
            $encrypted = ConvertFrom-SecureString $secureString
            return @{
                _encrypted = $true
                _value = $encrypted
            }
        }
        catch {
            Write-Warning "Failed to encrypt value: $_"
            return $Value
        }
    }
    
    function Process-Hashtable {
        param([hashtable]$Hash)
        
        $result = @{}
        foreach ($key in $Hash.Keys) {
            $value = $Hash[$key]
            
            if ($value -is [hashtable]) {
                $result[$key] = Process-Hashtable $value
            }
            elseif ($key -in $sensitiveKeys -and $value -is [string]) {
                $result[$key] = Protect-Value $value
            }
            else {
                $result[$key] = $value
            }
        }
        return $result
    }
    
    return Process-Hashtable $Config
}

function Unprotect-SensitiveConfiguration {
    <#
    .SYNOPSIS
        Decrypts sensitive configuration values
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )
    
    function Unprotect-Value {
        param($Value)
        
        if ($Value -is [hashtable] -and $Value._encrypted) {
            try {
                $secureString = ConvertTo-SecureString $Value._value
                $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
                return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
            }
            catch {
                Write-Warning "Failed to decrypt value: $_"
                return $null
            }
        }
        return $Value
    }
    
    function Process-Hashtable {
        param([hashtable]$Hash)
        
        $result = @{}
        foreach ($key in $Hash.Keys) {
            $value = $Hash[$key]
            
            if ($value -is [hashtable] -and -not $value._encrypted) {
                $result[$key] = Process-Hashtable $value
            }
            else {
                $result[$key] = Unprotect-Value $value
            }
        }
        return $result
    }
    
    return Process-Hashtable $Config
}

# Update Set-GitZoomConfig
function Set-GitZoomConfig {
    param([hashtable]$Settings, [string]$Path = (Get-Location))
    
    # ... existing code ...
    
    # Protect sensitive values before saving
    $protectedConfig = Protect-SensitiveConfiguration -Config $config
    
    # Save with atomic operation
    Save-ConfigAtomic -Config $protectedConfig -ConfigFile $configFile
}

# Update Get-GitZoomConfig
function Get-GitZoomConfig {
    param([string]$Path = (Get-Location))
    
    # ... existing code to load config ...
    
    # Unprotect sensitive values after loading
    $config = Unprotect-SensitiveConfiguration -Config $configHash
    
    return $config
}
```

---

### Fix #5: Atomic File Operations

**File:** `lib/Configuration.ps1`
**Severity:** CRITICAL

#### Implementation:
```powershell
function Save-ConfigAtomic {
    <#
    .SYNOPSIS
        Saves configuration file atomically to prevent corruption
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,
        
        [Parameter(Mandatory)]
        [string]$ConfigFile
    )
    
    $tempFile = "$ConfigFile.tmp.$(Get-Random)"
    $backupFile = "$ConfigFile.bak"
    
    try {
        # Validate config before saving
        $validation = Test-GitZoomConfig -Config $Config
        if (-not $validation.IsValid) {
            throw "Invalid configuration: $($validation.Errors -join '; ')"
        }
        
        # Write to temporary file
        $json = $Config | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($tempFile, $json, [System.Text.Encoding]::UTF8)
        
        # Verify temp file was written correctly
        if (-not (Test-Path $tempFile)) {
            throw "Failed to write temporary configuration file"
        }
        
        # Backup existing file
        if (Test-Path $ConfigFile) {
            Copy-Item $ConfigFile $backupFile -Force
        }
        
        # Atomic move (rename)
        Move-Item $tempFile $ConfigFile -Force
        
        # Verify final file
        if (-not (Test-Path $ConfigFile)) {
            throw "Configuration file not found after save"
        }
        
        # Remove backup on success
        if (Test-Path $backupFile) {
            Remove-Item $backupFile -Force -ErrorAction SilentlyContinue
        }
        
        Write-Verbose "Configuration saved successfully"
    }
    catch {
        Write-Error "Failed to save configuration: $_"
        
        # Attempt to restore from backup
        if (Test-Path $backupFile) {
            try {
                Copy-Item $backupFile $ConfigFile -Force
                Write-Warning "Restored configuration from backup"
            }
            catch {
                Write-Error "Failed to restore from backup: $_"
            }
        }
        
        throw
    }
    finally {
        # Cleanup temporary files
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}
```

---

### Fix #6: Secure Temporary Files

**File:** `lib/Utilities.ps1`
**Severity:** CRITICAL

#### Implementation:
```powershell
function New-SecureGitZoomTempDirectory {
    <#
    .SYNOPSIS
        Creates a secure temporary directory with proper permissions
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Use .NET's secure temp path generation
        $tempPath = [System.IO.Path]::GetTempPath()
        $gitZoomTemp = Join-Path $tempPath "GitZoom"
        
        # Create base directory if it doesn't exist
        if (-not (Test-Path $gitZoomTemp)) {
            $null = New-Item -Path $gitZoomTemp -ItemType Directory -Force
        }
        
        # Generate cryptographically random directory name
        $randomBytes = New-Object byte[] 16
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $rng.GetBytes($randomBytes)
        $randomName = [System.BitConverter]::ToString($randomBytes) -replace '-', ''
        
        $tempDir = Join-Path $gitZoomTemp $randomName
        
        # Create directory
        $dir = New-Item -Path $tempDir -ItemType Directory -Force
        
        # Set restrictive permissions (Windows only)
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            $acl = Get-Acl $tempDir
            
            # Disable inheritance
            $acl.SetAccessRuleProtection($true, $false)
            
            # Remove all existing rules
            $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }
            
            # Add rule for current user only
            $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $currentUser,
                "FullControl",
                "ContainerInherit,ObjectInherit",
                "None",
                "Allow"
            )
            $acl.AddAccessRule($rule)
            
            # Apply ACL
            Set-Acl $tempDir $acl
        }
        else {
            # Unix-like systems: set permissions to 700
            chmod 700 $tempDir 2>$null
        }
        
        Write-Verbose "Created secure temp directory: $tempDir"
        return $tempDir
    }
    catch {
        Write-Error "Failed to create secure temp directory: $_"
        throw
    }
}
```

---

### Fix #7: Thread-Safe Performance Metrics

**File:** `lib/Performance.ps1`
**Severity:** CRITICAL

#### Implementation:
```powershell
# Add at module level
$Script:MetricsLock = [System.Threading.ReaderWriterLockSlim]::new()

function Add-PerformanceMetric {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Operation,
        
        [Parameter(Mandatory)]
        [double]$Duration,
        
        [bool]$Success = $true
    )
    
    $Script:MetricsLock.EnterWriteLock()
    try {
        # Initialize if needed
        if (-not $Script:PerformanceMetrics.Operations.ContainsKey($Operation)) {
            $Script:PerformanceMetrics.Operations[$Operation] = @{
                Count = 0
                TotalTime = 0
                AverageTime = 0
                MinTime = [double]::MaxValue
                MaxTime = 0
                LastExecuted = Get-Date
                SuccessRate = 0
                Failures = 0
            }
        }
        
        # Update metrics
        $metric = $Script:PerformanceMetrics.Operations[$Operation]
        $metric.Count++
        $metric.TotalTime += $Duration
        $metric.AverageTime = $metric.TotalTime / $metric.Count
        $metric.MinTime = [Math]::Min($metric.MinTime, $Duration)
        $metric.MaxTime = [Math]::Max($metric.MaxTime, $Duration)
        $metric.LastExecuted = Get-Date
        
        if (-not $Success) {
            $metric.Failures++
        }
        $metric.SuccessRate = (($metric.Count - $metric.Failures) / $metric.Count) * 100
        
        # Update global metrics
        $Script:PerformanceMetrics.OperationCount++
        $Script:PerformanceMetrics.TotalTime += $Duration
        
        # Implement size limit to prevent memory leak
        $maxOperations = 1000
        if ($Script:PerformanceMetrics.Operations.Count -gt $maxOperations) {
            # Remove oldest 10%
            $toRemove = [Math]::Floor($maxOperations * 0.1)
            $oldest = $Script:PerformanceMetrics.Operations.GetEnumerator() |
                Sort-Object { $_.Value.LastExecuted } |
                Select-Object -First $toRemove
            
            foreach ($old in $oldest) {
                $Script:PerformanceMetrics.Operations.Remove($old.Key)
            }
        }
