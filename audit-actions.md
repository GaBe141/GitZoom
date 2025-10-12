# Audit actions performed

On 2025-10-12 the following safe cleanup changes were prepared/applied by the automated audit assistant:

1. Updated `.gitignore` to ignore `.vscode-extension/node_modules/` and `.vscode-extension/out/`.
2. Added `test-data/legacy/README.md` to explain archived test files.
3. Added `scripts/perform-cleanup.ps1` which moves `file*.txt` from the repo root into `test-data/legacy/` and can optionally commit the move.

How to revert:

 - To undo the gitignore change: remove the added lines and commit.
 - To restore moved files: move them back from `test-data/legacy/` to the repo root and commit.
