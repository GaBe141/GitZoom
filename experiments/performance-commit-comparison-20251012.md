# GitZoom performance — commit comparison (2025-10-12)

This short report visualizes measurements we collected while benchmarking Git operations and our GitZoom tooling. The chart (SVG) compares single-commit timings and an end-to-end "Lightning Push" workflow recorded during experiments.

Files used

- `artifacts/measurement-20251012-000223.json` — baseline run (50 files) with timings in ms
- `experiments/performance-report-20251009-233320.json` — several operation timings (small-file commits, large-file commit, GitZoom lightning push, fetch, push)

Key numbers

- Baseline Commit (50 files): 45 ms (from `artifacts/measurement-20251012-000223.json` — Results.Baseline Commit)
- Commit (10 small files): 70 ms (from `experiments/performance-report-20251009-233320.json`)
- Commit (1MB file): 74 ms (from `experiments/performance-report-20251009-233320.json`)
- GitZoom Lightning Push (stage + commit + push): 2160 ms (from `experiments/performance-report-20251009-233320.json`)
- Git Fetch: 529 ms; Git Push: 906 ms (both from the same performance report)

What the chart shows

- A compact bar chart with the measured durations in milliseconds for the listed operations.
- The single-commit timings (45–74 ms) are very small compared to the end-to-end Lightning Push (2160 ms) because the Lightning Push includes network operations (push, fetch) and other steps.

Ratios (quick math)

- Lightning Push vs Baseline Commit: 2160 / 45 ≈ 48× slower (not a like-for-like comparison — Lightning Push includes network steps).
- Commit small files vs Baseline: 70 / 45 ≈ 1.56× slower (different test sizes and counts matter).

Caveats and interpretation

- Not all measurements are directly comparable: some are single commit timings, others represent multi-step workflows (stage + commit + push). Use the chart to compare the magnitude and relative cost rather than as an exact like-for-like benchmark.
- Network latency and remote speed heavily affect push/fetch times, so those numbers will vary by environment.
- File counts and sizes differ between measurements. The small-files test used 10 files; the baseline run reports 50 files in the artifact but recorded a single commit time of 45 ms — check the raw artifacts to reproduce tests consistently.

Repro steps

1. Run the measurement harness: `pwsh experiments/measurement-harness.ps1` (ensure `pwsh` is available)
2. Inspect generated JSON in `artifacts/` (timestamped files)
3. Open `experiments/performance-commit-comparison-20251012.svg` to view the visualization

If you'd like, I can:

- Normalize timings to a per-file average for direct file-size-independent comparisons
- Re-run measurements multiple times and plot averages + error bars
- Produce a PNG export alongside the SVG for usage in slides or reports
