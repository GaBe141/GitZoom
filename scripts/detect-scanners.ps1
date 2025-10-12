$bins = @('semgrep','trivy','snyk','gitleaks','trufflehog','codeql')
foreach ($b in $bins) {
  $p = Get-Command $b -ErrorAction SilentlyContinue
  if ($p) { Write-Output "$b -> $($p.Path)" } else { Write-Output "$b -> NOT FOUND" }
}