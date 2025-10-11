# Performance Baseline and How to Run It

This document explains the purpose of the performance harness and how to run baseline measurements for GitZoom.

Overview

- The performance harness measures common operations that reflect GitZoom's USP: fast multi-repo status scans and lightning fetch operations.

- Results are written to JSON and CSV in the `artifacts/performance/` folder for tracking and regression detection.

Running the harness

1. From the repository root run:

   - PowerShell: .\tests\Performance\BaselineHarness.ps1 -Iterations 3
2. Artifacts are created at `artifacts/performance/baseline-<timestamp>.json` and `.csv`.

Interpretation

- AvgMs / MedianMs: Lower is better. Use Median to avoid skew from network blips.

- AvgMemDelta: Memory delta observed in the PowerShell process during the run. Use for regression detection.

Notes & Caveats

- Some scenarios issue real `git fetch` commands. These may block for credentials, network, or large repos. Consider running those scenarios in a CI environment with token-based auth or skip them locally.

- The harness measures the PowerShell process memory and elapsed wall-clock time. It is a simple, reproducible baseline, not a full profiler.

Integrating into CI

- Add a nightly GitHub Action job that checks out repository, installs prerequisites, runs the harness with CI-friendly scenarios, and uploads artifacts. See `.github/workflows` for patterns used in this repo.

Next steps

- Add threshold checks and failure modes (e.g., fail if AvgMs increases by > 30% compared to stored baseline).

- Expand scenarios to simulate large multi-repo operations and remote latencies.
