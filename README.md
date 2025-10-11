# ⚡ GitZoom - Lightning-Fast Git Workflows

```text
   ⚡🐙⚡
  GitZoom
```

> From Git-Slow to Git-Go in 60 seconds.

GitZoom is a small toolkit and set of workflows that aim to speed up common Git operations (staging, committing, pushing) with safe, low-risk optimizations and developer ergonomics.

## Quick Start

One-line installer (PowerShell):

```powershell
iwr -useb https://raw.githubusercontent.com/GaBe141/GitZoom/main/install-gitzoom.ps1 | iex
```

List recommendations (CLI):

```bash
node tools/gitzoom-cli/index.js recommend list --format json
```

Dry-run apply (creates backup, prints commands):

```bash
node tools/gitzoom-cli/index.js recommend apply --dry-run
```

Apply recommendations (creates backup and applies configs):

```bash
node tools/gitzoom-cli/index.js recommend apply
```

Interactive rollback (choose a backup to restore):

```bash
node tools/gitzoom-cli/index.js recommend rollback
```

Backups are JSON files stored at `.gitzoom/backups/backup-<timestamp>.json`. The backup contains a `prev` map with prior values (or `null` when a key was not set).

## Features

- Lightning push: stage, commit, and push with improved staging performance
- Recommendations & Safe Apply: scan for low-risk `git config` options, create backups, support dry-run, and rollback
- VS Code extension: run experiments and apply recommendations from the UI
- CLI: list/apply/rollback recommendations; compatible backup format with the extension

## Files of interest

- `experiments/` — PowerShell scripts and measurement harness
- `tools/gitzoom-cli/` — Node CLI prototype that mirrors extension apply/rollback flows
- `.vscode-extension/` — VS Code extension source and bundled output
- `.gitzoom/backups/` — backup directory created at runtime

---

— GaBe141
# ⚡ GitZoom - Lightning-Fast Git Workflows

```
    ⚡🐙⚡
   GitZoom
```

> **From Git-Slow to Git-Go in 60 seconds!**

Stop waiting for Git. Start zooming through commits, pushes, and deploys with GitZoom - the workflow optimizer that turns Git-pain into Git-gain!

 # ⚡ GitZoom - Lightning-Fast Git Workflows

 ```text
    ⚡🐙⚡
   GitZoom
 ```

 From Git-Slow to Git-Go in 60 seconds.

 GitZoom is a small toolkit and set of workflows that aim to speed up common Git operations (staging, committing, pushing) with safe, low-risk optimizations and developer ergonomics.

 ## Quick Start

 One-line installer (PowerShell):

 ```powershell
 iwr -useb https://raw.githubusercontent.com/GaBe141/GitZoom/main/install-gitzoom.ps1 | iex
 ```

 List recommendations (CLI):

 ```bash
 node tools/gitzoom-cli/index.js recommend list --format json
 ```

 Dry-run apply (creates backup, prints commands):

 ```bash
 node tools/gitzoom-cli/index.js recommend apply --dry-run
 ```

 Apply recommendations (creates backup and applies configs):

 ```bash
 node tools/gitzoom-cli/index.js recommend apply
 ```

 Interactive rollback (choose a backup to restore):

 ```bash
 node tools/gitzoom-cli/index.js recommend rollback
 ```

 Backups are JSON files stored at `.gitzoom/backups/backup-<timestamp>.json`. The backup contains a `prev` map with prior values (or `null` when a key was not set).

 ## Features

 - Lightning push: stage, commit, and push with improved staging performance
 - Recommendations & Safe Apply: scan for low-risk `git config` options, create backups, support dry-run, and rollback
 - VS Code extension: run experiments and apply recommendations from the UI
 - CLI: list/apply/rollback recommendations; compatible backup format with the extension

 ## Files of interest

 - `experiments/` — PowerShell scripts and measurement harness
 - `tools/gitzoom-cli/` — Node CLI prototype that mirrors extension apply/rollback flows
 - `.vscode-extension/` — VS Code extension source and bundled output
 - `.gitzoom/backups/` — backup directory created at runtime

 ---

 — GaBe141
- `Ctrl+Shift+G C` — Commit staged changes
- `Ctrl+Shift+G P` — Push to remote
- `Ctrl+Shift+G S` — Sync (pull + push)
- `Ctrl+Shift+G A` — Stage all changes
- `Ctrl+Shift+G Z` — Open Git panel

### 🧙‍♂️ Workflow Wizardry

- **Auto-fetch** — Stay synced automatically
- **Smart commits** — Stage files when committing
- **Rebase by default** — Cleaner history
- **Lightning editor** — No more Notepad delays

### 🧪 Optimization Engine

**MASSIVE Performance Improvements Achieved:**

- **Batch Operations** — faster file staging in many cases
- **Enhanced Lightning Push** — dramatic speedups for common workflows
- **Smart Caching** — improved IO performance for repeated operations
- **Performance Benchmarking** — comprehensive testing framework
- **VS Code Integration** — optimized settings and shortcuts

See `OPTIMIZATION_RESULTS.md` for detailed performance data.

### Recommendations & Safe Apply

GitZoom can make low-risk Git configuration recommendations to speed up staging and IO (for example `core.untrackedCache` and `core.fscache`). Both the VS Code extension and the CLI provide a safe apply flow which:

- Scans the repository for low-risk recommendations
- Creates a backup of current Git settings in `.gitzoom/backups/` before applying anything
- Supports a dry-run mode so you can preview the changes without applying
- Allows rollback to a previous backup if you want to restore prior settings

CLI examples:

```bash
# List recommendations (JSON or human):
node tools/gitzoom-cli/index.js recommend list --format json

# Dry-run apply (creates backup, prints commands but does not change configs):
node tools/gitzoom-cli/index.js recommend apply --dry-run

# Apply recommendations (creates backup and applies configs):
node tools/gitzoom-cli/index.js recommend apply

# Interactive rollback (choose a backup to restore):
node tools/gitzoom-cli/index.js recommend rollback
```

Backups are JSON files stored at `.gitzoom/backups/backup-<timestamp>.json`. The backup file contains a `prev` map with previous values (or `null` if not set). The VS Code extension uses the same backup directory so you can apply via CLI and rollback in the editor (or vice versa).

### 📊 Zoom Analytics

```powershell
zoom-stats  # See your workflow improvements
```

## 🎯 Why GitZoom?

| Problem | Solution |
|---|---|
| Slow commits (Notepad delays) | VS Code editor + smart config |
| Forgetting Git commands | One-command everything |
| Complex workflows | Automated best practices |
| No workflow insights | Built-in analytics |

## 🏃‍♂️ Speed Improvements

**Real user results (examples):**

- **Sarah** — 3-minute commits → 3-second commits
- **Mike** — 45-second pushes → 5-second pushes

## 📦 What's Included

```text
GitZoom/
├── lightning-push.ps1      # One-command push magic
├── gitzoom-helpers.ps1     # Workflow helper functions
├── vscode-settings.json    # Optimized VS Code config
├── vscode-keybindings.json # Lightning-fast shortcuts
└── install-gitzoom.ps1     # Auto-installer script
```

## 🎮 Commands

### Lightning Commands

```powershell
zoom "commit message"     # Lightning push (stage + commit + push)
zoom-status                # Repository overview with style
zoom-sync                  # Pull latest with rebase
zoom-branch "feat-name"   # Create and switch to branch
zoom-stats                 # Workflow speed analytics
zoom-help                  # Show all commands
```

### Legacy Support

All your existing commands are supported via legacy aliases.

```powershell
Quick-Status; Quick-Pull; Quick-Branch
```

## 🛠️ Installation Options

### Global Installation

```powershell
.\install-gitzoom.ps1 -Global -VSCode
```

### User Installation (Default)

```powershell
.\install-gitzoom.ps1 -VSCode
```

### Force Reinstall

```powershell
.\install-gitzoom.ps1 -Force
```

## 🎯 Supported Platforms

- ✅ Windows (PowerShell 5.1+)
- ✅ Windows (PowerShell 7+)

## 🎪 Community

### Speed Challenges

- Tag us with `#GitZoomGang`
- Share your before/after times

### Contributing

1. Fork the repo
2. Create a feature branch
3. Make changes and test
4. Submit a pull request

## 📈 Roadmap

- Linux & macOS support (coming)
- Web dashboard for team analytics
- GitHub Actions integration

## 🆘 Support

- [Installation Guide](docs/INSTALLATION.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

## 📜 License

MIT License

---

— GaBe141
```

## 🛠️ Installation Options

### Global Installation
```powershell
.\install-gitzoom.ps1 -Global -VSCode
```

### User Installation (Default)
```powershell
.\install-gitzoom.ps1 -VSCode
```

### Force Reinstall
```powershell
.\install-gitzoom.ps1 -Force
```

## 🎯 Supported Platforms

- ✅ Windows (PowerShell 5.1+)
- ✅ Windows (PowerShell 7+)

## 🎪 Community

### Speed Challenges

- Tag us with `#GitZoomGang`
- Share your before/after times

### Contributing

1. Fork the repo
2. Create a feature branch
3. Make changes and test
4. Submit a pull request

## 📈 Roadmap

- Linux & macOS support (coming)
- Web dashboard for team analytics
- GitHub Actions integration

## 🆘 Support

- [Installation Guide](docs/INSTALLATION.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

## 📜 License

MIT License

---

— GaBe141
