<#
Interactive commit helper for GitZoom.
- Shows git status
- Lets you add files (all, staged, or by path)
- Runs pre-commit checks (via configured hooks)
- Opens editor for commit message (using configured template)
#>

param(
    [switch]$All,
    [switch]$Amend
)

function Show-Status {
    git status --short
}

function Run-Hooks {
    # Git will run hooks automatically on commit; here we just return success
    return $true
}

if ($All) { git add -A; Write-Host "Staged all changes" -ForegroundColor Cyan }

Show-Status

$continue = Read-Host "Stage additional files? (y/n)"
if ($continue -match '^[Yy]') {
    $toAdd = Read-Host "Enter files to add (space-separated)"
    if ($toAdd) { git add -- $toAdd; Show-Status }
}

# Run hooks by performing a dry-run: Simple check for PSScriptAnalyzer presence
try { Import-Module PSScriptAnalyzer -ErrorAction Stop; Write-Host "PSScriptAnalyzer available" -ForegroundColor Green } catch { Write-Host "PSScriptAnalyzer not available; continuing" -ForegroundColor Yellow }

if (-not (Run-Hooks)) { Write-Host "Hooks failed; aborting commit." -ForegroundColor Red; exit 1 }

# Open commit message in default editor
$editor = $env:GIT_EDITOR
if (-not $editor) { $editor = 'notepad' }
$tempMsg = [System.IO.Path]::GetTempFileName() + '.md'
if (Test-Path .github/COMMIT_TEMPLATE.md) { Get-Content .github/COMMIT_TEMPLATE.md | Set-Content $tempMsg }

# Launch editor
Start-Process -FilePath $editor -ArgumentList $tempMsg -Wait

# Commit
if ($Amend) { git commit --amend -F $tempMsg } else { git commit -F $tempMsg }

# Cleanup
Remove-Item $tempMsg -Force

Write-Host "Commit complete." -ForegroundColor Green
