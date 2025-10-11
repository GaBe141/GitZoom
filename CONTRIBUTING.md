# Contributing to GitZoom

Thank you for contributing! This document explains the lightweight pre-commit checks and the recommended developer setup to keep commits fast.

## Git Hooks

We use a local `core.hooksPath` pointing to `.githooks/` to provide project-specific hooks. To enable hooks locally run:

```powershell
# from the repository root
git config core.hooksPath .githooks
```

### Pre-commit

The pre-commit hook runs quick checks:

- Runs PSScriptAnalyzer on staged PowerShell files (does not block if not installed)
- Runs quick unit tests tagged with `Fast` if tests changed

Install analyzer:

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser
```

### Commit-msg

The commit-msg hook enforces Conventional Commits (e.g., `feat(scope): description`).

## Fast unit tests

Tag fast unit tests with `[Tag('Fast')]` in your Pester tests to keep pre-commit test runs quick.

## Interactive helper

Use `scripts/gz-commit.ps1` to stage changes interactively and open a commit message template.

## Troubleshooting

- If hooks do not run, ensure `core.hooksPath` is set and your platform allows execution of scripts.
- If PSScriptAnalyzer is not installed, the pre-commit hook will warn but not block commits.

Happy hacking!
