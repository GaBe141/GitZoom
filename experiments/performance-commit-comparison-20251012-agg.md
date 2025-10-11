# Aggregated results — GitZoom tuning (2025-10-12)

Summary

- Harness runs: 10 iterations for pre-tuned and 10 iterations for tuned configuration (the harness was run in this session).
- Focus metric: `Commit` duration (ms) measured by the harness.

Key aggregated numbers (representative single aggregated artifact values):

- Pre-tuned (100 files) — Commit: 44 ms → 0.44 ms/file
- Tuned (100 files, `core.untrackedCache=true`) — Commit: 43 ms → 0.43 ms/file
- Baseline earlier run (50 files) — Commit: 45 ms → 0.90 ms/file
- GitZoom Lightning Push (context, not directly comparable) — 2160 ms

Interpretation

- The tuned workspace-local change (`core.untrackedCache=true`) produced a small improvement on the 100-file commit measurement (44 → 43 ms ≈ 2.3% improvement). This is measurable but small in this environment.
- The large difference between single-commit durations and the Lightning Push workflow is due to network operations (push/fetch) and other steps included in the Lightning Push measurement.

Recommendation

- Because the recommendation is low-risk and reversible, consider offering it as an opt-in workspace setting for users who primarily work with many files and staging operations.
- If we want a stronger evidence base before making an opinionated recommendation, run the harness across multiple machine environments or increase the number of iterations (e.g., N=30) and aggregate means + 95% confidence intervals.

What I changed during the session

- Applied `core.untrackedCache=true` locally (backup created in `.gitzoom/backups/`), ran the harness N=10, then restored the previous settings using the backup.

Files produced

- `experiments/performance-commit-comparison-20251012-agg.svg` — aggregated visualization
- `experiments/performance-commit-comparison-20251012-agg.md` — this summary report

Next steps (automatable)

1. Increase N to 30 and run the harness on CI machines to reduce noise.
2. Add per-file normalized plots and error bars (mean ± stddev) and export PNG for reports.
3. Add CI job to run the harness on PRs that touch performance-sensitive code and upload artifacts.
