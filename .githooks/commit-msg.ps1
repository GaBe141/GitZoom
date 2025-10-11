#!/usr/bin/env pwsh
# PowerShell commit-msg hook implementation
param([string]$CommitMsgFile = $args[0])

$pattern = '^(feat|fix|chore|docs|refactor|perf|test|ci)(\(.+\))?:\s.+$'
$msg = Get-Content $CommitMsgFile -Raw

if (-not ($msg -match $pattern)) {
    Write-Host "Commit message does not follow Conventional Commits." -ForegroundColor Red
    Write-Host "Expected: <type>(optional-scope): description" -ForegroundColor Yellow
    Write-Host "Example: feat(auth): add token refresh" -ForegroundColor Yellow
    exit 1
}

exit 0
