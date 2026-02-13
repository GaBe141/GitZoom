# GitZoom Advanced Configuration

## Install locations

- **User install:** Scripts and modules are copied into your user profile (e.g. `Documents\WindowsPowerShell` or `Documents\PowerShell`). The installer prints the exact path.
- **Global install:** Scripts are copied to a shared location; use `-Global` when running the installer (requires elevation).

## VS Code settings and keybindings

GitZoom provides recommended settings and keybindings in:

- `configs/vscode-settings.json` – Git and editor options (e.g. default editor, fetch, rebase).
- `configs/vscode-keybindings.json` – Shortcuts for commit, push, sync, stage all, open Git panel.

Apply them via the installer with `-VSCode`, or copy the contents into your user `settings.json` and `keybindings.json`. The experiments folder also has `vscode-optimization.ps1` for programmatic apply/backup/reset.

## Production scripts

| Script | Purpose |
| ------ | ------- |
| `scripts/lightning-push.ps1` | One-command push (original) |
| `scripts/enhanced-lightning-push.ps1` | Batch staging and optimizations |
| `scripts/zoom.ps1` | Entry point for `zoom` alias |
| `scripts/gitzoom-helpers.ps1` | Helper functions and aliases |

The installer wires these so that `zoom "message"` runs the intended pipeline (e.g. enhanced lightning push with batch ops).

## Experiments and benchmarks

Optional performance and workflow experiments live in `experiments/`. See [experiments/README.md](../experiments/README.md) for:

- Performance benchmarking
- Test data generation
- Optimization experiments
- VS Code optimization script

Generated test data and benchmark outputs are written to gitignored paths (`test-data/`, `test-results/`, etc.); see the experiments README and [STRUCTURE.md](STRUCTURE.md).

## Customizing behavior

- **Commit message template:** Configure in Git: `git config commit.template` or use your editor.
- **Default branch:** GitZoom uses your Git default (e.g. `main`); set with `git config init.defaultBranch main`.
- **Remote and push:** Standard Git config applies; GitZoom does not change remotes or push URLs.

## Repository layout

See [STRUCTURE.md](STRUCTURE.md) for where scripts, configs, docs, and experiments live and which paths are gitignored.
