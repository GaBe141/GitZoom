$paths = @(
  Join-Path $env:LOCALAPPDATA 'Packages\PythonSoftwareFoundation.Python.3.11_qbz5n2kfra8p0\LocalCache\local-packages\Python311\Scripts',
  Join-Path $env:USERPROFILE 'AppData\Local\Programs\Python\Python311\Scripts',
  'C:\Program Files\Python311\Scripts',
  'C:\Program Files (x86)\Python311-32\Scripts'
)
foreach ($p in $paths) {
  if (Test-Path $p) {
    Write-Output "Scanning $p"
    Get-ChildItem -Path $p -Filter 'semgrep*' -File -ErrorAction SilentlyContinue | ForEach-Object { Write-Output $_.FullName }
  } else {
    Write-Output "Not found: $p"
  }
}