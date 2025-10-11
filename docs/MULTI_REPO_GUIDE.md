# Multi-Repository Management

GitZoom includes powerful tools for managing multiple Git repositories simultaneously. These features are perfect for developers working with microservices, monorepos, or managing multiple projects.

## Overview

The multi-repository features provide:

- **Parallel Fetching**: Update multiple repositories simultaneously using PowerShell jobs
- **Batch Status Checking**: Get a dashboard view of all your repositories at once
- **Performance Optimized**: Leverages parallel execution for maximum speed
- **Flexible Discovery**: Automatically find repositories in directory structures

## Commands

### Invoke-GitFetchAll (alias: gzfa)

Fetches updates for multiple Git repositories in parallel.

#### Syntax

```powershell
Invoke-GitFetchAll [-Path] <string[]> [-Recurse] [-MaxParallel <int>] [-Timeout <int>]
```

#### Parameters

- **Path** (Required): Array of repository paths or parent directories
- **Recurse**: Search subdirectories for repositories
- **MaxParallel**: Maximum concurrent jobs (default: 8)
- **Timeout**: Timeout per repository in seconds (default: 300)

#### Examples

**Fetch all repositories in a directory:**
```powershell
Invoke-GitFetchAll -Path "C:\Projects"
gzfa "C:\Projects"  # Using alias
```

**Recursively fetch all nested repositories:**
```powershell
Invoke-GitFetchAll -Path "C:\Dev" -Recurse
```

**Fetch specific repositories:**
```powershell
Invoke-GitFetchAll -Path @("C:\Repo1", "C:\Repo2", "C:\Repo3")
```

**Limit parallel operations:**
```powershell
Invoke-GitFetchAll -Path "C:\Projects" -Recurse -MaxParallel 4
```

**Set custom timeout:**
```powershell
Invoke-GitFetchAll -Path "C:\SlowRemote" -Timeout 600  # 10 minutes
```

#### Output

Returns an array of objects with:

```powershell
[PSCustomObject]@{
    Repository = "MyProject"           # Repository name
    Path = "C:\Projects\MyProject"     # Full path
    Success = $true                     # Whether fetch succeeded
    Message = "Fetched successfully"   # Status message
    Duration = 1234                     # Time in milliseconds
}
```

#### Performance

On a typical workstation with 8 cores:
- **1 repository**: ~1-2 seconds
- **10 repositories**: ~2-3 seconds (vs ~15-20 sequential)
- **50 repositories**: ~8-12 seconds (vs ~80-100 sequential)

---

### Get-GitStatusAll (alias: gzsa)

Gets the status of multiple Git repositories in a single view.

#### Syntax

```powershell
Get-GitStatusAll [-Path] <string[]> [-Recurse] [-IncludeClean] [-Format <string>]
```

#### Parameters

- **Path** (Required): Array of repository paths or parent directories
- **Recurse**: Search subdirectories for repositories
- **IncludeClean**: Include repositories with no changes
- **Format**: Output format - Table (default), List, or GridView

#### Examples

**Check status of all projects:**
```powershell
Get-GitStatusAll -Path "C:\Projects"
gzsa "C:\Projects"  # Using alias
```

**Include clean repositories:**
```powershell
Get-GitStatusAll -Path "C:\Dev" -Recurse -IncludeClean
```

**Display in interactive grid:**
```powershell
Get-GitStatusAll -Path "C:\Projects" -Format GridView
```

**Show detailed list format:**
```powershell
Get-GitStatusAll -Path "C:\Projects" -Format List
```

**Check specific repositories:**
```powershell
@("C:\Repo1", "C:\Repo2") | Get-GitStatusAll -IncludeClean
```

#### Output

Returns an array of objects with:

```powershell
[PSCustomObject]@{
    Repository = "MyProject"           # Repository name
    Path = "C:\Projects\MyProject"     # Full path
    Branch = "main"                    # Current branch
    Status = "2 uncommitted, 1 ahead"  # Human-readable status
    Uncommitted = 2                    # Number of uncommitted files
    Ahead = 1                          # Commits ahead of remote
    Behind = 0                         # Commits behind remote
}
```

#### Status Indicators

- **Clean**: No uncommitted changes, in sync with remote
- **X uncommitted**: Has uncommitted files
- **X ahead**: Has unpushed commits
- **X behind**: Remote has commits not pulled
- **Multiple**: e.g., "2 uncommitted, 3 ahead, 1 behind"

---

## Common Workflows

### Daily Sync Routine

Start your day by syncing all repositories:

```powershell
# Fetch all updates in parallel
Invoke-GitFetchAll -Path "C:\Dev" -Recurse

# Check what needs attention
Get-GitStatusAll -Path "C:\Dev" -Recurse

# Or combine with GridView for interactive filtering
Get-GitStatusAll -Path "C:\Dev" -Recurse -Format GridView
```

### Microservices Management

Managing multiple services:

```powershell
# Define your microservices directory
$servicesPath = "C:\Projects\MyApp\services"

# Quick status check
Get-GitStatusAll -Path $servicesPath

# Fetch updates for all services
Invoke-GitFetchAll -Path $servicesPath -MaxParallel 10

# Find services with uncommitted work
Get-GitStatusAll -Path $servicesPath | Where-Object { $_.Uncommitted -gt 0 }

# Find services that need to be pushed
Get-GitStatusAll -Path $servicesPath | Where-Object { $_.Ahead -gt 0 }
```

### CI/CD Integration

Use in build scripts to verify repository states:

```powershell
# Verify all repos are clean before deployment
$status = Get-GitStatusAll -Path "C:\Build\Repos" -Recurse
$dirty = $status | Where-Object { $_.Status -ne "Clean" }

if ($dirty) {
    Write-Error "The following repos have uncommitted changes:"
    $dirty | Format-Table Repository, Status
    exit 1
}

# Fetch latest for all components
Invoke-GitFetchAll -Path "C:\Build\Repos" -Recurse -MaxParallel 12
```

### End of Day Cleanup

Ensure all work is committed:

```powershell
# Find all repos with uncommitted changes
$uncommitted = Get-GitStatusAll -Path "C:\Dev" -Recurse | 
    Where-Object { $_.Uncommitted -gt 0 }

if ($uncommitted) {
    Write-Host "⚠️  You have uncommitted changes in:" -ForegroundColor Yellow
    $uncommitted | Format-Table Repository, Status -AutoSize
} else {
    Write-Host "✅ All repositories are clean!" -ForegroundColor Green
}

# Find unpushed commits
$unpushed = Get-GitStatusAll -Path "C:\Dev" -Recurse | 
    Where-Object { $_.Ahead -gt 0 }

if ($unpushed) {
    Write-Host "⚠️  You have unpushed commits in:" -ForegroundColor Yellow
    $unpushed | Format-Table Repository, Branch, Ahead -AutoSize
}
```

---

## Performance Tips

### Optimize MaxParallel

The default of 8 parallel jobs works well for most systems. Adjust based on:

- **CPU cores**: Generally, use 1-2x your core count
- **Network speed**: Lower for slow connections
- **Repository size**: Fewer for large repos with slow remotes

```powershell
# For fast local network or SSD
Invoke-GitFetchAll -Path "C:\Projects" -MaxParallel 16

# For slow remote servers
Invoke-GitFetchAll -Path "C:\Projects" -MaxParallel 4
```

### Directory Structure

For best performance:
- Keep related repos in a common parent directory
- Use `-Recurse` sparingly on deep directory trees
- Exclude non-repo directories from your path

### Timeout Configuration

Adjust timeout based on your network:

```powershell
# Fast local network
Invoke-GitFetchAll -Path "C:\Projects" -Timeout 60

# Slow or unreliable connection
Invoke-GitFetchAll -Path "C:\Projects" -Timeout 900  # 15 minutes
```

---

## Troubleshooting

### No repositories found

**Problem**: "No Git repositories found in specified paths"

**Solutions**:
- Verify the path exists and contains `.git` directories
- Use `-Recurse` if repos are in subdirectories
- Check that you have read permissions

### Timeout errors

**Problem**: Some repositories timeout during fetch

**Solutions**:
- Increase `-Timeout` parameter
- Reduce `-MaxParallel` to avoid network saturation
- Check network connection and remote server status
- Verify repository remotes: `git remote -v`

### Slow performance

**Problem**: Operations are slower than expected

**Solutions**:
- Reduce `-MaxParallel` if CPU-bound
- Increase `-MaxParallel` if network-bound
- Use SSD storage for repositories
- Check for antivirus interfering with Git operations

### GridView not available

**Problem**: `-Format GridView` fails

**Solution**: GridView requires Windows PowerShell or PowerShell 7 with the Microsoft.PowerShell.GraphicalTools module:

```powershell
Install-Module Microsoft.PowerShell.GraphicalTools
```

---

## Integration with Other GitZoom Features

### Combine with Performance Tracking

```powershell
# Measure multi-repo fetch performance
Measure-Command {
    Invoke-GitFetchAll -Path "C:\Projects" -Recurse
}

# Use GitZoom's performance tracking
Measure-GitZoomOperation -Operation {
    Invoke-GitFetchAll -Path "C:\Projects" -Recurse
}
```

### Use with GitZoom Configuration

```powershell
# Set up default paths in your GitZoom config
Set-GitZoomConfig -CustomProperty @{
    MultiRepoPath = "C:\Dev\Projects"
}

# Then use in scripts
$config = Get-GitZoomConfig
Invoke-GitFetchAll -Path $config.MultiRepoPath -Recurse
```

---

## Advanced Scenarios

### Custom Filtering

Filter repositories before operations:

```powershell
# Get all repos
$allRepos = Get-ChildItem -Path "C:\Dev" -Directory -Recurse | 
    Where-Object { Test-Path (Join-Path $_.FullName ".git") }

# Filter for specific criteria (e.g., containing "service" in name)
$serviceRepos = $allRepos | Where-Object { $_.Name -match "service" }

# Fetch only service repos
$serviceRepos.FullName | Invoke-GitFetchAll
```

### Scheduled Tasks

Automate repository maintenance:

```powershell
# Create a scheduled task to fetch all repos nightly
$action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-Command `"Import-Module GitZoom; Invoke-GitFetchAll -Path 'C:\Dev' -Recurse`""
$trigger = New-ScheduledTaskTrigger -Daily -At 2am
Register-ScheduledTask -TaskName "NightlyRepoSync" -Action $action -Trigger $trigger
```

### Report Generation

Create HTML reports of repository status:

```powershell
$status = Get-GitStatusAll -Path "C:\Dev" -Recurse -IncludeClean

$html = $status | ConvertTo-Html -Title "Repository Status Report" -PreContent "<h1>Repository Status - $(Get-Date)</h1>"
$html | Out-File "C:\Reports\repo-status-$(Get-Date -Format 'yyyy-MM-dd').html"
```

---

## Best Practices

1. **Regular Fetching**: Run `Invoke-GitFetchAll` daily to stay updated
2. **Status Checks**: Use `Get-GitStatusAll` before end of day
3. **Automation**: Schedule regular sync operations
4. **Monitoring**: Keep GridView open for real-time repository overview
5. **Cleanup**: Periodically review and commit/stash uncommitted work

---

## See Also

- [GitZoom Performance Guide](PERFORMANCE_ANALYSIS.md)
- [GitZoom Configuration](../README.md#configuration)
- [Integration Tests](../tests/Integration/README.md)
