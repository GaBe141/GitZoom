# GitZoom Production Alias
# This script provides the 'zoom' command with optimized performance
param(
    [string]$message = "Quick update"
)

# Use the enhanced lightning push with optimized single-command staging
& "$PSScriptRoot\lightning-push.ps1" -message $message -Verbose