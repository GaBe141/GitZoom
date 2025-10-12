# Repository History Rewrite Plan

Proposed date/time (tentative): 2025-10-16 09:00 UTC

Purpose
-------
This document describes the planned rewrite of the git history to remove committed large artifacts (for example `.vscode-extension/node_modules/`) to reduce repository size and speed up clone/fetch/commit operations.

High-level plan
---------------
1. Create a full mirror backup of the repository.
2. Coordinate a short freeze window for pushing (announce to contributors).
3. Perform the rewrite in a mirror clone using `git-filter-repo` (or BFG) to remove the targeted paths.
4. Verify the resulting repo locally and run basic checks.
5. Force-push the rewritten refs to the remote.
6. Post-rewrite: notify contributors with instructions to re-clone or update their local repos.

Checklist — pre-steps (owner)
----------------------------
- [ ] Choose and confirm the final rewrite date/time with maintainers.
- [ ] Ensure at least one authoritative backup exists (mirror clone + tarball).
- [ ] Identify all paths to remove (e.g. `.vscode-extension/node_modules/`, `.vscode-extension/out/`).
- [ ] Prepare the `git-filter-repo` command(s) and test them in a disposable environment.
- [ ] Prepare a short announcement and PR with the plan (this file) for visibility.

Commands — backup (do this first, on a machine with good network)
---------------------------------------------------------------
```bash
# Mirror clone (bare) - creates a full copy including refs and tags
git clone --mirror https://github.com/GaBe141/GitZoom.git GitZoom.git
cd GitZoom.git
# Create a local compressed backup just in case
tar -czf ../GitZoom-mirror-backup-$(date -u +%Y%m%dT%H%M%SZ).tar.gz .
```

Commands — history rewrite (example using git-filter-repo)
--------------------------------------------------------
Note: test these commands in a throwaway clone before running against the backup copy.

```bash
# In the mirror clone created earlier
git filter-repo \
  --invert-paths --paths .vscode-extension/node_modules \
  --paths .vscode-extension/out

# Optional: run additional cleanups
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Verify results locally, e.g., repo size
du -sh .

# When ready, push to remote (FORCE PUSH)
git push --force --all
git push --force --tags
```

Alternative: BFG Repo-Cleaner
--------------------------------
BFG is another tool that can be simpler for common cases. See https://rtyley.github.io/bfg-repo-cleaner/ for usage examples.

Verification steps
------------------
- Inspect the rewritten history for removed paths: `git log --stat -- <path>` should show no history references.
- Run `git count-objects -vH` and record repo size before/after.
- Re-run Semgrep / linters in CI to ensure workflows still parse.

Contributor instructions (post-rewrite)
-------------------------------------
After the force-push, local clones will be incompatible. Contributors must either re-clone or run the recommended steps below:

1. Option A: Fresh clone (recommended)
   - `git clone https://github.com/GaBe141/GitZoom.git`

2. Option B: Rebase local work onto rewritten history (advanced users only)
   - Save local branches: `git for-each-ref --format='%(refname)' refs/heads/ > /tmp/my-branches.txt`
   - Create patches of local commits or temporarily push to a personal fork before recloning.

Rollback plan
-------------
- If something goes wrong, restore remote from the mirror backup by pushing the backup refs back to origin (requires contacting GitHub or using the mirror clone to force-push original refs).

Communication
-------------
Use the announcement file (`COMMUNICATION/HISTORY_REWRITE_ANNOUNCEMENT.md`) to notify contributors and maintainers. Include the freeze window and exact commands they must follow.

Contact
-------
Repo maintainers: GaBe141 (owner)
If you want me to perform the rewrite, explicitly confirm and I will run the commands in a mirror clone and coordinate the force-push.
