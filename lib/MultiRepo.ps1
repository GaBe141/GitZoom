<#
.SYNOPSIS
    Multi-repository management functions for GitZoom

.DESCRIPTION
    Provides functions to manage multiple Git repositories simultaneously,
    including parallel fetching and status checking across multiple repos.
#>

function Invoke-GitFetchAll {
    <#
    .SYNOPSIS
        Fetches updates for multiple Git repositories in parallel
    
    .DESCRIPTION
        Scans specified directories for Git repositories and runs 'git fetch --all --prune'
        on each repository in parallel using PowerShell jobs for maximum performance.
    
    .PARAMETER Path
        Array of repository paths to fetch. Can be individual repo paths or parent directories.
    
    .PARAMETER Recurse
        If specified, recursively searches for Git repositories in subdirectories.
    
    .PARAMETER MaxParallel
        Maximum number of parallel jobs to run. Default is 8.
    
    .PARAMETER Timeout
        Timeout in seconds for each fetch operation. Default is 300 (5 minutes).
    
    .EXAMPLE
        Invoke-GitFetchAll -Path "C:\Projects" -Recurse
        Fetches all repositories under C:\Projects
    
    .EXAMPLE
        Invoke-GitFetchAll -Path @("C:\Repo1", "C:\Repo2") -MaxParallel 4
        Fetches two specific repositories with a maximum of 4 parallel jobs
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]$Path,
        
        [switch]$Recurse,
        
        [int]$MaxParallel = 8,
        
        [int]$Timeout = 300
    )
    
    begin {
        $allPaths = @()
    }
    
    process {
        $allPaths += $Path
    }
    
    end {
        Write-Verbose "🔍 Scanning for Git repositories..."
        
        # Find all Git repositories
        $repositories = @()
        foreach ($pathItem in $allPaths) {
            if (-not (Test-Path $pathItem)) {
                Write-Warning "Path not found: $pathItem"
                continue
            }
            
            $item = Get-Item $pathItem
            
            if ($Recurse -and $item.PSIsContainer) {
                # Search for .git directories
                $gitDirs = Get-ChildItem -Path $pathItem -Directory -Filter ".git" -Recurse -ErrorAction SilentlyContinue
                foreach ($gitDir in $gitDirs) {
                    $repositories += $gitDir.Parent.FullName
                }
            } elseif (Test-Path (Join-Path $pathItem ".git")) {
                # Single repository
                $repositories += $item.FullName
            } elseif ($item.PSIsContainer) {
                # Check immediate children for repositories
                $children = Get-ChildItem -Path $pathItem -Directory -ErrorAction SilentlyContinue
                foreach ($child in $children) {
                    if (Test-Path (Join-Path $child.FullName ".git")) {
                        $repositories += $child.FullName
                    }
                }
            }
        }
        
        if ($repositories.Count -eq 0) {
            Write-Warning "No Git repositories found in specified paths"
            return
        }
        
        Write-Information "📦 Found $($repositories.Count) repositories"
        Write-Verbose "⚡ Starting parallel fetch (max $MaxParallel concurrent)..."
        
        $jobs = @()
        $results = @()
        $startTime = Get-Date
        
        # Create script block for parallel execution
        $fetchScript = {
            param($repoPath, $timeout)
            
            $result = [PSCustomObject]@{
                Repository = Split-Path $repoPath -Leaf
                Path = $repoPath
                Success = $false
                Message = ""
                Duration = 0
            }
            
            try {
                Push-Location $repoPath
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                
                # Run git fetch with timeout
                $process = Start-Process -FilePath "git" -ArgumentList "fetch", "--all", "--prune" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\gitfetch_$([guid]::NewGuid()).out" -RedirectStandardError "$env:TEMP\gitfetch_$([guid]::NewGuid()).err"
                
                if (-not $process.WaitForExit($timeout * 1000)) {
                    $process.Kill()
                    $result.Message = "Timeout after $timeout seconds"
                } elseif ($process.ExitCode -eq 0) {
                    $result.Success = $true
                    $result.Message = "Fetched successfully"
                } else {
                    $result.Message = "Fetch failed with exit code $($process.ExitCode)"
                }
                
                $stopwatch.Stop()
                $result.Duration = $stopwatch.ElapsedMilliseconds
                
            } catch {
                $result.Message = "Error: $($_.Exception.Message)"
            } finally {
                Pop-Location
            }
            
            return $result
        }
        
        # Start jobs in batches
        $index = 0
        while ($index -lt $repositories.Count -or $jobs.Count -gt 0) {
            # Start new jobs up to max parallel
            while ($jobs.Count -lt $MaxParallel -and $index -lt $repositories.Count) {
                $repo = $repositories[$index]
                $job = Start-Job -ScriptBlock $fetchScript -ArgumentList $repo, $Timeout
                $jobs += $job
                $index++
            }
            
            # Check for completed jobs
            $completedJobs = $jobs | Where-Object { $_.State -eq 'Completed' }
            foreach ($job in $completedJobs) {
                $result = Receive-Job -Job $job
                $results += $result
                Remove-Job -Job $job
                $jobs = $jobs | Where-Object { $_.Id -ne $job.Id }
                
                # Display progress
                if ($result.Success) {
                    Write-Information "  ✓ $($result.Repository) ($($result.Duration)ms)"
                } else {
                    Write-Warning "  ✗ $($result.Repository): $($result.Message)"
                }
            }
            
            Start-Sleep -Milliseconds 100
        }
        
        $totalDuration = ((Get-Date) - $startTime).TotalSeconds
        
    # Summary
    Write-Information "`n📊 Fetch Summary:"
    Write-Information "  Total repositories: $($results.Count)"
    Write-Information "  Successful: $($results | Where-Object Success | Measure-Object | Select-Object -ExpandProperty Count)"
    Write-Information "  Failed: $($results | Where-Object { -not $_.Success } | Measure-Object | Select-Object -ExpandProperty Count)"
    Write-Verbose "  Total time: $([math]::Round($totalDuration, 2))s"
        
        return $results
    }
}

function Get-GitStatusAll {
    <#
    .SYNOPSIS
        Gets the status of multiple Git repositories
    
    .DESCRIPTION
        Scans specified directories for Git repositories and displays a summary
        of each repository's status including uncommitted changes, unpushed commits,
        and current branch information.
    
    .PARAMETER Path
        Array of repository paths to check. Can be individual repo paths or parent directories.
    
    .PARAMETER Recurse
        If specified, recursively searches for Git repositories in subdirectories.
    
    .PARAMETER IncludeClean
        If specified, includes repositories with no changes in the output.
    
    .PARAMETER Format
        Output format: Table (default), List, or GridView.
    
    .EXAMPLE
        Get-GitStatusAll -Path "C:\Projects" -Recurse
        Gets status of all repositories under C:\Projects
    
    .EXAMPLE
        Get-GitStatusAll -Path @("C:\Repo1", "C:\Repo2") -Format GridView
        Shows status in an interactive grid view
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]$Path,
        
        [switch]$Recurse,
        
        [switch]$IncludeClean,
        
        [ValidateSet("Table", "List", "GridView")]
        [string]$Format = "Table"
    )
    
    begin {
        $allPaths = @()
    }
    
    process {
        $allPaths += $Path
    }
    
    end {
    Write-Verbose "🔍 Scanning for Git repositories..."
        
        # Find all Git repositories
        $repositories = @()
        foreach ($pathItem in $allPaths) {
            if (-not (Test-Path $pathItem)) {
                Write-Warning "Path not found: $pathItem"
                continue
            }
            
            $item = Get-Item $pathItem
            
            if ($Recurse -and $item.PSIsContainer) {
                # Search for .git directories
                $gitDirs = Get-ChildItem -Path $pathItem -Directory -Filter ".git" -Recurse -ErrorAction SilentlyContinue
                foreach ($gitDir in $gitDirs) {
                    $repositories += $gitDir.Parent.FullName
                }
            } elseif (Test-Path (Join-Path $pathItem ".git")) {
                # Single repository
                $repositories += $item.FullName
            } elseif ($item.PSIsContainer) {
                # Check immediate children for repositories
                $children = Get-ChildItem -Path $pathItem -Directory -ErrorAction SilentlyContinue
                foreach ($child in $children) {
                    if (Test-Path (Join-Path $child.FullName ".git")) {
                        $repositories += $child.FullName
                    }
                }
            }
        }
        
        if ($repositories.Count -eq 0) {
            Write-Warning "No Git repositories found in specified paths"
            return
        }
        
    Write-Information "📦 Checking status of $($repositories.Count) repositories...`n"

        $statuses = @()
        
        foreach ($repo in $repositories) {
            try {
                Push-Location $repo
                
                # Get current branch
                $branch = git rev-parse --abbrev-ref HEAD 2>$null
                
                # Get status
                $statusLines = git status --porcelain 2>$null
                $uncommitted = ($statusLines | Measure-Object).Count
                
                # Check for unpushed commits
                $unpushed = 0
                $behind = 0
                
                if ($branch -and $branch -ne "HEAD") {
                    # Check if branch has upstream
                    $upstream = git rev-parse --abbrev-ref "@{u}" 2>$null
                    
                    if ($upstream) {
                        $aheadBehind = git rev-list --left-right --count "$upstream...$branch" 2>$null
                        if ($aheadBehind) {
                            $parts = $aheadBehind -split '\s+'
                            $behind = [int]$parts[0]
                            $unpushed = [int]$parts[1]
                        }
                    }
                }
                
                # Determine status
                $status = "Clean"
                if ($uncommitted -gt 0 -or $unpushed -gt 0 -or $behind -gt 0) {
                    $statusParts = @()
                    if ($uncommitted -gt 0) { $statusParts += "$uncommitted uncommitted" }
                    if ($unpushed -gt 0) { $statusParts += "$unpushed ahead" }
                    if ($behind -gt 0) { $statusParts += "$behind behind" }
                    $status = $statusParts -join ", "
                }
                
                $repoStatus = [PSCustomObject]@{
                    Repository = Split-Path $repo -Leaf
                    Path = $repo
                    Branch = $branch
                    Status = $status
                    Uncommitted = $uncommitted
                    Ahead = $unpushed
                    Behind = $behind
                }
                
                if ($IncludeClean -or $status -ne "Clean") {
                    $statuses += $repoStatus
                }
                
                Pop-Location
                
            } catch {
                # Delimit the variable to avoid parser/linter confusion with the following ':' character
                Write-Warning "Error checking repository ${repo}: $($_.Exception.Message)"
                Pop-Location
            }
        }
        
        # Display results
        if ($statuses.Count -eq 0) {
            Write-Information "✅ All repositories are clean!"
            return
        }
        
        switch ($Format) {
            "Table" {
                $statuses | Format-Table -Property Repository, Branch, Status -AutoSize
            }
            "List" {
                foreach ($s in $statuses) {
                    # Display with semantic streams so analyzers can filter
                    Write-Information "`n📁 $($s.Repository)"
                    Write-Verbose "   Path: $($s.Path)"
                    Write-Verbose "   Branch: $($s.Branch)"
                    if ($s.Status -eq 'Clean') { Write-Information "   Status: $($s.Status)" } else { Write-Warning "   Status: $($s.Status)" }
                }
            }
            "GridView" {
                $statuses | Select-Object Repository, Branch, Status, Uncommitted, Ahead, Behind, Path | Out-GridView -Title "Git Repository Status"
            }
        }
        
    # Summary
    Write-Information "`n📊 Summary:"
    Write-Information "  Total repositories: $($repositories.Count)"
    Write-Information "  With changes: $($statuses.Count)"
    Write-Information "  Clean: $(($repositories.Count - $statuses.Count))"
        
        return $statuses
    }
}

# Create aliases
New-Alias -Name gzfa -Value Invoke-GitFetchAll -Force
New-Alias -Name gzsa -Value Get-GitStatusAll -Force

# Export functions
Export-ModuleMember -Function Invoke-GitFetchAll, Get-GitStatusAll -Alias gzfa, gzsa
