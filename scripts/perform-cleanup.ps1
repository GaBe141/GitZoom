<#
Safe cleanup script: moves root-level file*.txt into test-data/legacy/
Usage:
  pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/perform-cleanup.ps1 [-Commit]

Options:
  -Commit : if present, the script will git add/move and create a commit with message "chore: archive root file*.txt into test-data/legacy/"
#>

param(
  [switch]$Commit
)

$dest = Join-Path -Path (Get-Location) -ChildPath "test-data\legacy"
if (-not (Test-Path $dest)) {
  New-Item -ItemType Directory -Path $dest -Force | Out-Null
  Write-Output "Created $dest"
} else {
  Write-Output "$dest already exists"
}

$files = Get-ChildItem -Path (Get-Location) -Filter "file*.txt" -File -ErrorAction SilentlyContinue
if (-not $files) {
  Write-Output "No file*.txt files found in repo root. Nothing to do."
  return
}

foreach ($f in $files) {
  $target = Join-Path -Path $dest -ChildPath $f.Name
  Write-Output "Moving $($f.FullName) -> $target"
  Move-Item -Path $f.FullName -Destination $target -Force
}

if ($Commit) {
  git add test-data/legacy
  git rm --cached -r .vscode-extension/node_modules 2>$null
  git add .gitignore
  git commit -m "chore: archive root file*.txt into test-data/legacy/ and ignore .vscode-extension node_modules"
  Write-Output "Committed cleanup changes"
} else {
  Write-Output "Run again with -Commit to create a git commit for these changes."
}
