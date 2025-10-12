<#
.SYNOPSIS
Removes the local semgrep virtualenv created during scans.

.DESCRIPTION
Deletes the `.venv-semg` directory if it exists. This is safe to run and will not touch other venvs.
#>
Param()

Write-Host "Checking for .venv-semg..."
if (Test-Path -Path ".venv-semg") {
    Write-Host "Removing .venv-semg..."
    Remove-Item -Recurse -Force -Path ".venv-semg"
    Write-Host "Removed .venv-semg"
} else {
    Write-Host ".venv-semg not found. Nothing to do."
}
