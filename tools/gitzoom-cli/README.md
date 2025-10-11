GitZoom CLI

Usage:

- Run an experiment:

  gitzoom run experiments/staging-champion.ps1 --format human

# GitZoom CLI

GitZoom CLI

Usage

- Run an experiment:

```bash
gitzoom run experiments/staging-champion.ps1 --format human
```

- Show recommendations:

```bash
gitzoom recommend --format json
```

This is a minimal prototype. Future improvements:

- Add structured metrics output for CI
- Add apply/rollback and dry-run
- Convert to TypeScript and add tests

## Recommendations & Safe Apply

The CLI supports a safe apply flow for low-risk Git configuration recommendations (same as the VS Code extension). Backups are created before applying changes and stored at `.gitzoom/backups/`.

Usage examples:

```bash
# Show recommendations (human or JSON):
node tools/gitzoom-cli/index.js recommend list --format json

# Dry-run apply (writes a backup, prints the commands but does not change configs):
node tools/gitzoom-cli/index.js recommend apply --dry-run

# Apply recommendations (writes a backup and applies changes):
node tools/gitzoom-cli/index.js recommend apply

# Interactive rollback (choose a backup to restore):
node tools/gitzoom-cli/index.js recommend rollback
```

Backup format example:

```json
{
  "timestamp": "2025-10-11T22:10:56.094Z",
  "prev": {
    "core.untrackedCache": null
  }
}
```

Notes:

- Backups created by the CLI are compatible with the VS Code extension (they share the `.gitzoom/backups/` folder).
- For CI or automation, a non-interactive `--file <backup.json>` restore flag can be added on request.

---

— GaBe141
