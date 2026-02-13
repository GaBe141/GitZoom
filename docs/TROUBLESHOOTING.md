# GitZoom Troubleshooting

## Git not found

**Symptom:** Scripts report that Git is not installed or not on PATH.

**Fix:**

1. Install [Git for Windows](https://git-scm.com/download/win) and ensure "Git from the command line and also from 3rd-party software" is selected.
2. Restart your terminal (or VS Code) so PATH updates.
3. Run `git --version` to confirm.

## Execution policy errors

**Symptom:** PowerShell reports that script execution is disabled.

**Fix:**

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

For one-time bypass in the current session:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-gitzoom.ps1
```

## zoom / zoom-help not recognized

**Symptom:** `zoom` or other GitZoom commands are unknown after install.

**Fix:**

1. Ensure the install script completed without errors.
2. Check that the install target (user or global) is on your PATH. User installs typically go under `$env:USERPROFILE\Documents\WindowsPowerShell` or similar; the installer prints the path.
3. Close and reopen your terminal (and VS Code if you use it).
4. Re-run the installer with `-Force` if the scripts were overwritten or moved.

## Lightning push fails or is slow

**Symptom:** `zoom "message"` or enhanced-lightning-push fails or doesn’t feel faster.

**Checks:**

- Run `git status` in the repo; fix any repo/working tree issues first.
- Ensure you have a remote and push is allowed: `git remote -v`, `git push --dry-run`.
- For speed: use batch staging (e.g. `-EnableBatchOps` where supported); see [OPTIMIZATION_RESULTS.md](../OPTIMIZATION_RESULTS.md).

## VS Code shortcuts not working

**Symptom:** Ctrl+Shift+G or other GitZoom keybindings do nothing.

**Fix:**

1. Confirm VS Code config was applied: installer with `-VSCode` or run the VS Code optimization experiment.
2. Check for conflicts: File > Preferences > Keyboard Shortcuts, search for the key combination.
3. Ensure you’re in a folder that is a Git repository when using Git-related shortcuts.

## Still stuck?

- Open an [issue](https://github.com/GaBe141/GitZoom/issues) with your PowerShell version (`$PSVersionTable`), Git version (`git --version`), and the exact command and error message.
