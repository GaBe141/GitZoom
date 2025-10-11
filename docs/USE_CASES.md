# GitZoom Performance Use Cases

This page describes the user scenarios that the performance harness targets and why they're important.

1. Large multi-repo status scan

- Teams with many repositories need a quick status overview to know which repos need push/pull, saving context-switch time.

1. Lightning fetch across repositories

- Running parallel fetch operations across many repos should complete significantly faster than sequential fetches, especially with I/O-bound network operations.

1. Interactive commit paths

- Developers using `gz-commit` and `gzfa` should experience minimal latency when staging and syncing across repos.

Running these in CI

- Use CI tokens to run fetch scenarios non-interactively.

- Pin iterations and run multiple times to reduce noise.

Metrics to watch

- Time-to-complete per scenario (ms)

- Memory delta of the harness process

- Success rate (network errors, auth failures)
