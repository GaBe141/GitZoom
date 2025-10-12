<#
This script prepares instructions for removing large node_modules directories from history using git-filter-repo.
It does NOT modify history automatically. Review and run the steps manually on a clean clone when ready.

Prerequisites:
- Install git-filter-repo (https://github.com/newren/git-filter-repo)
- Ensure you have a backup and coordinate with the team because this will require a force-push.

Example manual steps:

1. Make a fresh clone of the repository (do not run in your working repo):
   git clone --mirror git@github.com:GaBe141/GitZoom.git
   cd GitZoom.git

2. Run git-filter-repo to remove the folder(s):
   git filter-repo --path .vscode-extension/node_modules --invert-paths

   # If multiple folders:
   git filter-repo --path .vscode-extension/node_modules --path .vscode-extension/out --invert-paths

3. Verify the repository, then push back to remote:
   git push --force --all
   git push --force --tags

4. Instruct contributors to reclone or run commands to rebind their remotes.

NOTE: Alternatively use the BFG Repo-Cleaner for a simpler interface but still destructive.
#>

Write-Host "This file contains instructions. Do not run this script in-place."
