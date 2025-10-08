#!/usr/bin/env pwsh
# GitZoom Helper Functions - Lightning-fast Git workflow utilities

Write-Host "⚡ GitZoom helpers loaded! Type 'Show-GitZoomHelp' for commands" -ForegroundColor Cyan

function Show-GitZoomHelp {
    Write-Host "⚡ GitZoom Helper Commands:" -ForegroundColor Cyan
    Write-Host "  Show-GitStatus        - Repository status overview" -ForegroundColor White
    Write-Host "  Sync-GitRepository    - Pull latest changes with rebase" -ForegroundColor White
    Write-Host "  New-GitBranch <name>  - Create and switch to new branch" -ForegroundColor White
    Write-Host "  Get-GitZoomStats      - Show workflow speed statistics" -ForegroundColor White
    Write-Host ""
    Write-Host "🔄 Legacy Aliases (for compatibility):" -ForegroundColor Yellow
    Write-Host "  Quick-Status, Quick-Pull, Quick-Branch" -ForegroundColor DarkYellow
    Write-Host ""
    Write-Host "🚀 Pro Tip: Use 'lightning-push.ps1' for one-command commits!" -ForegroundColor Green
}

function Show-GitStatus {
    Write-Host "📊 GitZoom Repository Status:" -ForegroundColor Cyan
    git status --short --branch
    Write-Host ""
    Write-Host "🌳 Current Branch:" -ForegroundColor Cyan
    git branch --show-current
    Write-Host ""
    Write-Host "📈 Recent Commits:" -ForegroundColor Cyan
    git log --oneline -5
    Write-Host ""
    Write-Host "⚡ Powered by GitZoom" -ForegroundColor DarkGray
}

function Sync-GitRepository {
    Write-Host "🔄 GitZoom syncing repository..." -ForegroundColor Yellow
    git fetch --prune
    git pull --rebase
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Repository synced and zoomed!" -ForegroundColor Green
    } else {
        Write-Host "❌ Sync failed - check for conflicts" -ForegroundColor Red
    }
}

function New-GitBranch {
    param([string]$branchName)
    
    if (-not $branchName) {
        Write-Host "📋 Available branches:" -ForegroundColor Cyan
        git branch -a
        Write-Host ""
        Write-Host "💡 Usage: New-GitBranch 'feature-name'" -ForegroundColor Yellow
        return
    }
    
    Write-Host "🌿 GitZoom creating branch: $branchName" -ForegroundColor Yellow
    git checkout -b $branchName
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Branch created and switched! You're zooming on: $branchName" -ForegroundColor Green
    } else {
        Write-Host "❌ Branch creation failed!" -ForegroundColor Red
    }
}

function Get-GitZoomStats {
    Write-Host "⚡ GitZoom Workflow Statistics:" -ForegroundColor Cyan
    Write-Host ""
    
    $commitCount = (git rev-list --count HEAD 2>$null)
    if ($commitCount) {
        Write-Host "📈 Total Commits: $commitCount" -ForegroundColor Green
    }
    
    $branchCount = (git branch -r | Measure-Object).Count
    Write-Host "🌿 Remote Branches: $branchCount" -ForegroundColor Green
    
    $lastCommit = git log -1 --format="%cr" 2>$null
    if ($lastCommit) {
        Write-Host "🕐 Last Commit: $lastCommit" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "🚀 Keep zooming with GitZoom!" -ForegroundColor Magenta
}

# Legacy aliases for backward compatibility
Set-Alias -Name Quick-Status -Value Show-GitStatus
Set-Alias -Name Quick-Pull -Value Sync-GitRepository
Set-Alias -Name Quick-Branch -Value New-GitBranch

# GitZoom aliases
Set-Alias -Name zoom-status -Value Show-GitStatus
Set-Alias -Name zoom-sync -Value Sync-GitRepository
Set-Alias -Name zoom-branch -Value New-GitBranch
Set-Alias -Name zoom-help -Value Show-GitZoomHelp
Set-Alias -Name zoom-stats -Value Get-GitZoomStats

# Functions are automatically available when script is dot-sourced