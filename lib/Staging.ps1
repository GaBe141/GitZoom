<#
.SYNOPSIS
    GitZoom Advanced Staging Module
    
.DESCRIPTION
    Provides optimized file staging operations using intelligent batching,
    pattern recognition, and Windows-specific optimizations for maximum performance.
#>

#region Staging Operations

<#
.SYNOPSIS
    Performs optimized file staging with intelligent batching
    
.DESCRIPTION
    Advanced staging operation that categorizes files, processes them in batches,
    and applies optimizations based on file types and sizes for maximum performance.
    
.PARAMETER Path
    Files or patterns to stage
    
.PARAMETER All
    Stage all modified and new files
    
.PARAMETER Force
    Force add files that would normally be ignored
    
.PARAMETER Batch
    Enable batch processing (default: true)
    
.EXAMPLE
    Invoke-OptimizedStaging -Path "*.js"
    
.EXAMPLE
    Invoke-OptimizedStaging -All -Batch
#>
function Invoke-OptimizedStaging {
    [CmdletBinding()]
    param(
        [string[]]$Path,
        [switch]$All,
        [switch]$Force,
        [switch]$Batch
    )
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $results = @{
        AddedFiles = @()
        Errors = @()
        Performance = @{}
    }
    
    try {
        Write-Verbose "Starting optimized staging operation..."
        
        # Get files to stage
        if ($All) {
            $filesToStage = Get-UnstagedFiles -IncludeUntracked
        }
        else {
            $filesToStage = Get-FilesFromPatterns -Patterns $Path
        }
        
        if (-not $filesToStage -or $filesToStage.Count -eq 0) {
            Write-Verbose "No files to stage"
            return $results
        }
        
        Write-Verbose "Found $($filesToStage.Count) files to stage"
        
        # Categorize files for optimal processing
        $categorizedFiles = Invoke-FileAnalysis -Files $filesToStage
        
        # Determine staging strategy
        $config = Get-GitZoomConfig
        $strategy = Get-StagingStrategy -FileCount $filesToStage.Count -Config $config
        
        Write-Verbose "Using staging strategy: $($strategy.Name)"
        
        # Execute staging based on strategy
        switch ($strategy.Type) {
            "SingleBatch" {
                $results = Invoke-SingleBatchStaging -Files $filesToStage -Force:$Force
            }
            "MultiBatch" {
                $results = Invoke-MultiBatchStaging -CategorizedFiles $categorizedFiles -Force:$Force -BatchSize $strategy.BatchSize
            }
            "Parallel" {
                $results = Invoke-ParallelStaging -CategorizedFiles $categorizedFiles -Force:$Force -MaxJobs $strategy.MaxJobs
            }
            "Individual" {
                $results = Invoke-IndividualStaging -Files $filesToStage -Force:$Force
            }
        }
        
        # Performance tracking
        $results.Performance.TotalTime = $stopwatch.ElapsedMilliseconds
        $results.Performance.Strategy = $strategy.Name
        $results.Performance.FilesPerSecond = if ($stopwatch.ElapsedMilliseconds -gt 0) {
            [math]::Round(($results.AddedFiles.Count / $stopwatch.ElapsedMilliseconds) * 1000, 2)
        } else { 0 }
        
    }
    catch {
        $results.Errors += $_.Exception.Message
        Write-Error "Staging operation failed: $($_.Exception.Message)"
    }
    finally {
        $stopwatch.Stop()
    }
    
    return $results
}

<#
.SYNOPSIS
    Gets unstaged files from the repository
    
.DESCRIPTION
    Efficiently retrieves a list of files that are modified, new, or deleted
    and need to be staged for commit.
    
.PARAMETER IncludeUntracked
    Include untracked files in the results
    
.EXAMPLE
    Get-UnstagedFiles -IncludeUntracked
#>
function Get-UnstagedFiles {
    [CmdletBinding()]
    param(
        [switch]$IncludeUntracked
    )
    
    try {
        $files = @()
        
        # Get git status in porcelain format for easy parsing
        $statusOutput = git status --porcelain 2>$null
        
        if ($LASTEXITCODE -eq 0 -and $statusOutput) {
            foreach ($line in $statusOutput) {
                if ($line.Length -ge 3) {
                    $status = $line.Substring(0, 2)
                    $filename = $line.Substring(3).Trim('"')
                    
                    # Include files based on status
                    $shouldInclude = $false
                    
                    # Modified files (not staged)
                    if ($status[1] -eq 'M' -or $status[1] -eq 'D') {
                        $shouldInclude = $true
                    }
                    
                    # Untracked files
                    if ($IncludeUntracked -and $status[0] -eq '?' -and $status[1] -eq '?') {
                        $shouldInclude = $true
                    }
                    
                    # New files (partially staged)
                    if ($status[0] -eq 'A' -and $status[1] -eq 'M') {
                        $shouldInclude = $true
                    }
                    
                    if ($shouldInclude) {
                        $files += $filename
                    }
                }
            }
        }
        
        return $files
    }
    catch {
        Write-Error "Failed to get unstaged files: $($_.Exception.Message)"
        return @()
    }
}

<#
.SYNOPSIS
    Expands file patterns into actual file paths
    
.DESCRIPTION
    Takes glob patterns and expands them into concrete file paths,
    handling wildcards and directory traversal efficiently.
    
.PARAMETER Patterns
    Array of file patterns to expand
    
.EXAMPLE
    Get-FilesFromPatterns -Patterns @("*.js", "src/**/*")
#>
function Get-FilesFromPatterns {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Patterns
    )
    
    $files = @()
    
    try {
        foreach ($pattern in $Patterns) {
            if (Test-Path $pattern) {
                # Direct file or directory
                if (Test-Path $pattern -PathType Container) {
                    # Directory - get all files recursively
                    $dirFiles = Get-ChildItem -Path $pattern -File -Recurse |
                        ForEach-Object { $_.FullName }
                    $files += $dirFiles
                }
                else {
                    # Single file
                    $files += (Resolve-Path $pattern).Path
                }
            }
            else {
                # Pattern with wildcards
                try {
                    $matchingFiles = Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue |
                        ForEach-Object { $_.FullName }
                    $files += $matchingFiles
                }
                catch {
                    # Pattern didn't match anything
                    Write-Verbose "Pattern '$pattern' did not match any files"
                }
            }
        }
        
        # Convert to relative paths for Git
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if ($gitRoot) {
            $relativePaths = @()
            foreach ($file in $files) {
                $relativePath = [System.IO.Path]::GetRelativePath($gitRoot, $file)
                $relativePaths += $relativePath -replace '\\', '/'
            }
            return $relativePaths
        }
        
        return $files
    }
    catch {
        Write-Error "Failed to expand file patterns: $($_.Exception.Message)"
        return @()
    }
}

<#
.SYNOPSIS
    Analyzes files and categorizes them for optimal processing
    
.DESCRIPTION
    Examines files by size, type, and characteristics to determine
    the best processing strategy for staging operations.
    
.PARAMETER Files
    Array of file paths to analyze
    
.EXAMPLE
    Invoke-FileAnalysis -Files @("app.js", "data.json", "image.png")
#>
function Invoke-FileAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Files
    )
    
    $categories = @{
        Small = @()          # < 1MB
        Medium = @()         # 1MB - 10MB  
        Large = @()          # > 10MB
        Binary = @()         # Binary files
        Text = @()           # Text files
        Special = @()        # Special handling required
    }
    
    try {
        foreach ($file in $Files) {
            $fileInfo = $null
            $isBinary = $false
            $size = 0
            
            # Get file information if it exists
            if (Test-Path $file) {
                $fileInfo = Get-Item $file -ErrorAction SilentlyContinue
                if ($fileInfo) {
                    $size = $fileInfo.Length
                    $isBinary = Test-BinaryFile -Path $file
                }
            }
            
            # Categorize by size
            if ($size -lt 1MB) {
                $categories.Small += $file
            }
            elseif ($size -lt 10MB) {
                $categories.Medium += $file
            }
            else {
                $categories.Large += $file
            }
            
            # Categorize by type
            if ($isBinary) {
                $categories.Binary += $file
            }
            else {
                $categories.Text += $file
            }
            
            # Special files that need careful handling
            $extension = [System.IO.Path]::GetExtension($file).ToLower()
            $specialExtensions = @('.exe', '.dll', '.msi', '.zip', '.7z', '.rar', '.iso', '.bin')
            if ($extension -in $specialExtensions) {
                $categories.Special += $file
            }
        }
        
        Write-Verbose "File analysis complete:"
        Write-Verbose "  Small files: $($categories.Small.Count)"
        Write-Verbose "  Medium files: $($categories.Medium.Count)" 
        Write-Verbose "  Large files: $($categories.Large.Count)"
        Write-Verbose "  Binary files: $($categories.Binary.Count)"
        Write-Verbose "  Text files: $($categories.Text.Count)"
        Write-Verbose "  Special files: $($categories.Special.Count)"
        
        return $categories
    }
    catch {
        Write-Error "File analysis failed: $($_.Exception.Message)"
        return $categories
    }
}

<#
.SYNOPSIS
    Determines the optimal staging strategy based on file characteristics
    
.DESCRIPTION
    Analyzes the number and types of files to determine the most efficient
    staging approach (single batch, multi-batch, parallel, or individual).
    
.PARAMETER FileCount
    Number of files to stage
    
.PARAMETER Config
    GitZoom configuration object
    
.EXAMPLE
    Get-StagingStrategy -FileCount 150 -Config $config
#>
function Get-StagingStrategy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$FileCount,
        
        [Parameter(Mandatory)]
        [hashtable]$Config
    )
    
    $strategy = @{
        Type = "SingleBatch"
        Name = "Single Batch"
        BatchSize = 0
        MaxJobs = 1
    }
    
    try {
        $perfConfig = $Config.Performance
        $maxThreshold = $perfConfig.MaxFileThreshold
        $batchSize = $perfConfig.BatchSize
        $maxJobs = $perfConfig.MaxParallelJobs
        
        if ($FileCount -le 5) {
            # Very few files - process individually for precision
            $strategy = @{
                Type = "Individual"
                Name = "Individual Processing"
                BatchSize = 1
                MaxJobs = 1
            }
        }
        elseif ($FileCount -le $batchSize) {
            # Small number - single batch
            $strategy = @{
                Type = "SingleBatch"
                Name = "Single Batch"
                BatchSize = $FileCount
                MaxJobs = 1
            }
        }
        elseif ($FileCount -le $maxThreshold) {
            # Medium number - multi-batch
            $strategy = @{
                Type = "MultiBatch" 
                Name = "Multi-Batch Processing"
                BatchSize = $batchSize
                MaxJobs = 1
            }
        }
        else {
            # Large number - parallel processing if enabled
            if ($perfConfig.ParallelOperations) {
                $strategy = @{
                    Type = "Parallel"
                    Name = "Parallel Processing"
                    BatchSize = $batchSize
                    MaxJobs = [Math]::Min($maxJobs, [Math]::Ceiling($FileCount / $batchSize))
                }
            }
            else {
                $strategy = @{
                    Type = "MultiBatch"
                    Name = "Large Multi-Batch"
                    BatchSize = $batchSize
                    MaxJobs = 1
                }
            }
        }
        
        return $strategy
    }
    catch {
        Write-Error "Failed to determine staging strategy: $($_.Exception.Message)"
        return $strategy
    }
}

<#
.SYNOPSIS
    Executes single-batch staging operation
    
.DESCRIPTION
    Stages all files in a single git add command for maximum efficiency
    when dealing with small to medium numbers of files.
    
.PARAMETER Files
    Array of files to stage
    
.PARAMETER Force
    Force add files that would normally be ignored
    
.EXAMPLE
    Invoke-SingleBatchStaging -Files @("file1.js", "file2.js") -Force
#>
function Invoke-SingleBatchStaging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Files,
        
        [switch]$Force
    )
    
    $results = @{
        AddedFiles = @()
        Errors = @()
    }
    
    try {
        $gitArgs = @("add")
        if ($Force) { $gitArgs += "--force" }
        $gitArgs += $Files
        
        Write-Verbose "Executing single batch staging for $($Files.Count) files"
        
        $output = & git @gitArgs 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $results.AddedFiles = $Files
            Write-Verbose "Successfully staged $($Files.Count) files in single batch"
        }
        else {
            $results.Errors += "Git add failed: $output"
        }
    }
    catch {
        $results.Errors += $_.Exception.Message
    }
    
    return $results
}

<#
.SYNOPSIS
    Executes multi-batch staging operation
    
.DESCRIPTION
    Processes files in multiple batches to handle large numbers of files
    efficiently while avoiding command-line length limitations.
    
.PARAMETER CategorizedFiles
    Files categorized by analysis
    
.PARAMETER Force
    Force add files that would normally be ignored
    
.PARAMETER BatchSize
    Number of files per batch
    
.EXAMPLE
    Invoke-MultiBatchStaging -CategorizedFiles $files -BatchSize 50
#>
function Invoke-MultiBatchStaging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CategorizedFiles,
        
        [switch]$Force,
        
        [int]$BatchSize = 50
    )
    
    $results = @{
        AddedFiles = @()
        Errors = @()
    }
    
    try {
        # Process files by category for optimal performance
        $processOrder = @("Small", "Text", "Medium", "Binary", "Large", "Special")
        
        foreach ($category in $processOrder) {
            $categoryFiles = $CategorizedFiles[$category]
            if (-not $categoryFiles -or $categoryFiles.Count -eq 0) {
                continue
            }
            
            Write-Verbose "Processing $($categoryFiles.Count) $category files"
            
            # Process in batches
            for ($i = 0; $i -lt $categoryFiles.Count; $i += $BatchSize) {
                $endIndex = [Math]::Min($i + $BatchSize - 1, $categoryFiles.Count - 1)
                $batch = $categoryFiles[$i..$endIndex]
                
                $gitArgs = @("add")
                if ($Force) { $gitArgs += "--force" }
                $gitArgs += $batch
                
                Write-Verbose "Staging batch $([Math]::Floor($i / $BatchSize) + 1) of $category files ($($batch.Count) files)"
                
                $output = & git @gitArgs 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $results.AddedFiles += $batch
                }
                else {
                    $results.Errors += "Batch staging failed for $category files: $output"
                    # Continue with other batches even if one fails
                }
            }
        }
    }
    catch {
        $results.Errors += $_.Exception.Message
    }
    
    return $results
}

<#
.SYNOPSIS
    Tests if a file is binary
    
.DESCRIPTION
    Quickly determines if a file contains binary content by examining
    the first few bytes for null characters and non-printable content.
    
.PARAMETER Path
    Path to the file to test
    
.EXAMPLE
    Test-BinaryFile -Path "image.png"
#>
function Test-BinaryFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    try {
        if (-not (Test-Path $Path)) {
            return $false
        }
        
        $bytes = [System.IO.File]::ReadAllBytes($Path) | Select-Object -First 1024
        
        # Check for null bytes (common in binary files)
        if ($bytes -contains 0) {
            return $true
        }
        
        # Check for high percentage of non-printable characters
        $nonPrintable = 0
        foreach ($byte in $bytes) {
            if ($byte -lt 32 -and $byte -ne 9 -and $byte -ne 10 -and $byte -ne 13) {
                $nonPrintable++
            }
        }
        
        $nonPrintableRatio = $nonPrintable / $bytes.Count
        return $nonPrintableRatio -gt 0.1  # More than 10% non-printable
    }
    catch {
        # If we can't read the file, assume it's binary
        return $true
    }
}

<#
.SYNOPSIS
    Placeholder for parallel staging implementation
    
.DESCRIPTION
    Future implementation for parallel file staging using PowerShell jobs
    or runspaces for maximum performance with very large file sets.
#>
function Invoke-ParallelStaging {
    [CmdletBinding()]
    param(
        [hashtable]$CategorizedFiles,
        [switch]$Force,
        [int]$MaxJobs = 4
    )
    
    # For now, fall back to multi-batch staging
    # TODO: Implement true parallel staging using runspaces
    return Invoke-MultiBatchStaging -CategorizedFiles $CategorizedFiles -Force:$Force
}

<#
.SYNOPSIS
    Executes individual file staging for precision control
    
.DESCRIPTION
    Stages files one by one for maximum control and error isolation.
    Used for small numbers of files or when precision is critical.
#>
function Invoke-IndividualStaging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Files,
        
        [switch]$Force
    )
    
    $results = @{
        AddedFiles = @()
        Errors = @()
    }
    
    foreach ($file in $Files) {
        try {
            $gitArgs = @("add")
            if ($Force) { $gitArgs += "--force" }
            $gitArgs += $file
            
            $output = & git @gitArgs 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $results.AddedFiles += $file
            }
            else {
                $results.Errors += "Failed to stage '$file': $output"
            }
        }
        catch {
            $results.Errors += "Exception staging '$file': $($_.Exception.Message)"
        }
    }
    
    return $results
}

#endregion

# Export functions (handled by module manifest)
# Export-ModuleMember -Function @(
#     "Invoke-OptimizedStaging",
#     "Get-UnstagedFiles",
#     "Get-FilesFromPatterns",
#     "Invoke-FileAnalysis",
#     "Get-StagingStrategy",
#     "Test-BinaryFile"
# )