# Upcoming Repository History Rewrite — Action Required

Planned date/time (tentative): **2025-10-16 09:00 UTC**

Purpose
-------
To reduce repository size and improve developer experience (faster clones, fetches, and commits) we will remove large committed artifacts from history such as `.vscode-extension/node_modules/` and other build outputs.

What will change
---------------
- The Git history will be rewritten to remove specified folders/files from all commits.
- The remote repository will be force-updated with the rewritten history.

Impact to contributors
----------------------
After the rewrite, local clones will be incompatible with the rewritten remote history. You must either re-clone the repository or follow the advanced update steps below.

Freeze window
-------------
- Start: 2025-10-16 08:30 UTC — stop merging or pushing changes to avoid conflicts.
- Rewrite: 2025-10-16 09:00 UTC — maintainers will perform the rewrite and force-push.
- End: 2025-10-16 09:30 UTC — when the new history is published and verified.

What you must do (recommended)
-----------------------------
1. Before the freeze (recommended):
   - Push any outstanding branches to your fork or save patches: `git push origin HEAD:refs/for/backup-branches/your-branch`
   - Note any local work you haven't pushed.

2. After the rewrite (recommended — easiest):
   - Delete your old clone and re-clone the repository:
     ```bash
     rm -rf GitZoom
     git clone https://github.com/GaBe141/GitZoom.git
     cd GitZoom
     ```

3. Advanced update (for power users only):
   - If you can't re-clone (large local changes), follow the documented advanced steps in `docs/HISTORY_REWRITE_PLAN.md` under "Contributor instructions (post-rewrite)". This is error-prone; re-cloning is strongly recommended.

Support
-------
- If you need assistance during the window, reach out on Slack or open an issue titled "HISTORY REWRITE HELP" so maintainers can assist.

Questions / Concerns
-------------------
Please comment on this PR (or open an issue) if this freeze window conflicts with your work. We can adjust the schedule if necessary.

Thank you for helping keep the repository healthy and fast!
