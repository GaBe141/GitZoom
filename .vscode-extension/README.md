# GitZoom VS Code Extension (Prototype)

This is a minimal prototype VS Code extension that adds a command to run experiment scripts and stream output to an Output channel.

How it works:
- Command: `GitZoom: Run Experiment`
- Presents a quick pick of known experiment scripts
- Runs the selected PowerShell script using PowerShell Core (`pwsh`) and captures stdout/stderr to the `GitZoom Experiments` output channel

Notes:
- This is a prototype. For a production extension you should bundle the extension, add configuration for script discovery, and handle process lifecycle more robustly.

## Recommendations & Safe Apply

The extension can scan your workspace for low-risk Git recommendations (for example `core.untrackedCache` and `core.fscache`) and offer to apply them.

Before applying any changes the extension creates a JSON backup in `.gitzoom/backups/` containing previous values so you can rollback if needed. Backups are compatible with the CLI (they share the same folder).

Use the `GitZoom: Recommendations Menu` command (status bar) to view recommendations, apply them, or restore a previous backup via the `Rollback` command.
