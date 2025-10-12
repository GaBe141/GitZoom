# Inventory script - safe, read-only
Write-Output "=== GIT BRANCH ==="
git rev-parse --abbrev-ref HEAD

Write-Output "=== LAST COMMIT ==="
git log -1 --pretty=format:'%h %an %ad %s'

Write-Output "=== GIT STATUS ==="
git status --porcelain

Write-Output "=== MANIFESTS & CI FILES ==="
Get-ChildItem -Path . -Recurse -Force -ErrorAction SilentlyContinue -Include package.json, yarn.lock, requirements.txt, pyproject.toml, setup.py, Pipfile, Pipfile.lock, *.csproj, global.json, Dockerfile, docker-compose*.yml, .github\workflows\* | Select-Object FullName | ForEach-Object { $_.FullName }

Write-Output "=== LARGE FILES (>5MB) ==="
Get-ChildItem -Path . -Recurse -Force -File | Where-Object { $_.Length -gt 5MB } | Select-Object FullName,@{Name='MB';Expression={[math]::Round($_.Length/1MB,2)}} | Format-Table -AutoSize

Write-Output "=== TOP 50 FILES BY SIZE ==="
Get-ChildItem -Path . -Recurse -Force -File | Sort-Object Length -Descending | Select-Object -First 50 FullName,@{Name='MB';Expression={[math]::Round($_.Length/1MB,2)}} | Format-Table -AutoSize
