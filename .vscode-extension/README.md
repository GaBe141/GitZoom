# GitZoom VS Code Extension (Prototype)

This is a minimal prototype VS Code extension that adds a command to run experiment scripts and stream output to an Output channel.

How it works:
- Command: `GitZoom: Run Experiment`
- Presents a quick pick of known experiment scripts
- Runs the selected PowerShell script using PowerShell Core (`pwsh`) and captures stdout/stderr to the `GitZoom Experiments` output channel

Notes:
- This is a prototype. For a production extension you should bundle the extension, add configuration for script discovery, and handle process lifecycle more robustly.
