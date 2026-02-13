# Test data (legacy)

These notes describe the former `test-data/legacy/` folder. The `test-data/` directory is now gitignored; this doc is kept for reference.

## What was in test-data/legacy

Files were moved from the repository root into that folder during a cleanup operation.

**Why:**

- Keep the repository root tidy while preserving generated/test data.

**How to restore:**

- To restore a file, move it back to the repository root and commit.

**Notes:**

- Files are preserved in git history. The folder was intended for legacy/test artifacts only.

## Current policy

Generated test data lives in `test-data/` (gitignored). Use the experiments scripts to recreate it:

- `experiments\test-data-generator.ps1`
- `experiments\windows-test-data-generator.ps1`

See [experiments/README.md](../experiments/README.md) for details.
