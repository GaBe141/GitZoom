# GitZoom Installation Guide

## Prerequisites

- **Windows** with PowerShell 5.1 or PowerShell 7+
- **Git** installed and on your PATH
- Optional: **VS Code** for editor integration and shortcuts

## One-Command Install (recommended)

```powershell
iwr -useb https://raw.githubusercontent.com/GaBe141/GitZoom/main/install-gitzoom.ps1 | iex
```

Or from a local clone:

```powershell
.\install-gitzoom.ps1
```

## Installation options

### User installation (default)

Scripts and config are installed for your user only:

```powershell
.\install-gitzoom.ps1 -VSCode
```

### Global installation

Install for all users (requires elevation):

```powershell
.\install-gitzoom.ps1 -Global -VSCode
```

### VS Code integration

- **`-VSCode`** – Copy optimized settings and keybindings into your VS Code user config.
- Settings live in `configs/vscode-settings.json` and `configs/vscode-keybindings.json`.

### Force reinstall

Overwrite existing install:

```powershell
.\install-gitzoom.ps1 -Force
```

## NPM / npx (optional)

If you use Node.js:

```bash
npx gitzoom
# or
npm install -g gitzoom
```

See [package.json](../package.json) for `install`, `install-global`, and `install-vscode` scripts.

## Verify installation

```powershell
zoom-help
zoom-status
```

If these commands run, GitZoom is installed and on your PATH.

## Next steps

- [Troubleshooting](TROUBLESHOOTING.md) – Fix common issues
- [Advanced Configuration](ADVANCED.md) – Customize GitZoom
