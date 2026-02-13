# Repository layout

This document describes where scripts, configs, docs, and generated outputs live.

## Root

- **README.md** – Project overview, quick start, commands
- **LICENSE** – MIT license
- **package.json** – NPM package config and scripts (`install`, `install-global`, `install-vscode`)
- **install-gitzoom.ps1** – One-command installer
- **\*.md** – Project summaries, setup guides, and optimization results (e.g. PROJECT_SUMMARY.md, GITHUB_SETUP.md, OPTIMIZATION_RESULTS.md)

## scripts/

Production PowerShell scripts used by the installer and daily workflow:

- **lightning-push.ps1** – One-command push (original)
- **enhanced-lightning-push.ps1** – Batch staging and optimizations
- **zoom.ps1** – Entry point for the `zoom` alias
- **gitzoom-helpers.ps1** – Helper functions and aliases (zoom-status, zoom-sync, etc.)
- **ultra-fast-commit.ps1** – Additional commit automation

## configs/

VS Code configuration applied when you install with `-VSCode`:

- **vscode-settings.json** – Git and editor settings
- **vscode-keybindings.json** – Lightning shortcuts (e.g. Ctrl+Shift+G)

## experiments/

Optional benchmarks and optimization experiments. Not required for normal GitZoom use. See [experiments/README.md](../experiments/README.md) for:

- Canonical scripts (performance-benchmark, test-data-generator, continuous-testing, etc.)
- Optional variants (turbo and ram-disk family)
- How to generate test data and run benchmarks

## docs/

Project and setup documentation:

- **INSTALLATION.md** – Install options and verification
- **TROUBLESHOOTING.md** – Common issues and fixes
- **ADVANCED.md** – Config locations, production scripts, experiments overview
- **STRUCTURE.md** – This file
- **test-data-legacy.md** – Notes on the former test-data/legacy folder

## Test outputs and generated data (gitignored)

These paths are not committed; they are listed in `.gitignore`:

- **test-data/** – Generated test files from experiments (recreate with `test-data-generator.ps1` or `windows-test-data-generator.ps1`)
- **test-results/** – Continuous-testing and benchmark outputs
- **TestResults/**, **TestResults.xml** – Pester or other test result outputs
- **tests/TestResults/** – Test run artifacts under `tests/`

Committed test fixtures, if needed, should go in a dedicated folder such as `tests/fixtures/` or `sample-data/`.
