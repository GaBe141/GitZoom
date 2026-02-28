# AGENTS.md

## Cursor Cloud specific instructions

**GitZoom** is a PowerShell-based CLI toolkit that optimizes common Git workflows (stage + commit + push). It has no build step, no web server, no database, and no runtime npm dependencies. The `package.json` is metadata-only (for `npx` installation) and has `"os": ["win32"]`; `npm install` will fail on Linux with `EBADPLATFORM` — this is expected and harmless.

### Prerequisites

- **PowerShell Core (`pwsh`)** must be installed (the update script handles this). All scripts are `.ps1` files.
- **Git** is required and expected to be on `PATH`.

### Running scripts

All scripts live in `scripts/` and `experiments/`. Run them with:

```bash
pwsh -ExecutionPolicy Bypass -File scripts/<script>.ps1
```

Key commands for development verification:

| Command | Purpose |
|---------|---------|
| `pwsh -ExecutionPolicy Bypass -Command '. ./scripts/gitzoom-helpers.ps1; Show-GitZoomHelp'` | List all helper commands |
| `pwsh -ExecutionPolicy Bypass -Command '. ./scripts/gitzoom-helpers.ps1; Show-GitStatus'` | Repo status overview |
| `pwsh -ExecutionPolicy Bypass -Command '. ./scripts/gitzoom-helpers.ps1; Get-GitZoomStats'` | Workflow statistics |
| `pwsh -ExecutionPolicy Bypass -File scripts/zoom.ps1 -message "msg"` | Run the `zoom` alias (stage+commit+push) |
| `pwsh -ExecutionPolicy Bypass -File scripts/enhanced-lightning-push.ps1 -message "msg" -EnableBatchOps -Verbose` | Enhanced push with batch ops |

### Gotchas

- `install-gitzoom.ps1` uses Windows-style paths (`$env:USERPROFILE\.gitzoom`). On Linux it resolves to `/.gitzoom` and fails with access-denied errors on the copy step. The script flow and prerequisite checks still work.
- The test-data generator (`experiments/test-data-generator.ps1`) creates files under `test-data/` which is gitignored. Clean up with `rm -rf test-data`.
- There is no formal test framework (Pester, etc.) or linter configured. Validation is done by running the scripts directly and inspecting output.
- The `package.json` `"os": ["win32"]` field causes `npm install` to fail on Linux — this is expected and does not affect development.
