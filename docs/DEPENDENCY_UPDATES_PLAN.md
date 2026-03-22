# Dependency Updates Plan

> Scanned: March 15, 2026 | Repository: GitZoom v1.0.0

## Executive Summary

GitZoom is a PowerShell-based CLI toolkit with **zero npm runtime or dev dependencies**. The `package.json` is metadata-only (used for `npx` publishing). The project's real dependencies are external tools: **PowerShell** and **Git**, referenced throughout the `.ps1` scripts but not version-pinned at runtime.

This plan covers: package.json metadata hygiene, PowerShell version policy, Git version policy, and recommended tooling additions.

---

## 1. Dependency Inventory

| Dependency | Type | Declared Version | Current Latest | Status |
|---|---|---|---|---|
| npm packages (`dependencies`) | runtime | _(none)_ | — | N/A |
| npm packages (`devDependencies`) | dev | _(none)_ | — | N/A |
| PowerShell | runtime (engine) | `>=5.1` | 7.5.4 (stable), 7.4.13 (LTS) | ⚠️ See below |
| Git | runtime (implicit) | _(not declared)_ | 2.50.1 | ⚠️ See below |

---

## 2. Findings

### 2.1 `package.json` Metadata Issues

**No npm vulnerabilities** — the package has zero `dependencies` / `devDependencies`, so there is nothing to audit via `npm audit`.

| Issue | Severity | Detail |
|---|---|---|
| Non-standard `engines.powershell` field | Low | npm only recognizes `engines.node` and `engines.npm`. The `"powershell": ">=5.1"` key is silently ignored by npm; it serves as documentation only. |
| Missing `engines.node` field | Low | Even though the package doesn't use Node at runtime, specifying a minimum Node version is good practice for `npx`-based installation. |
| `"main": "install-gitzoom.ps1"` | Low | The `main` field normally points to a JS entry point. For a non-JS package this is cosmetic but could confuse tooling. Consider replacing with `"bin"` if a wrapper script is warranted, or removing. |
| No `"type"` field | Informational | Modern npm convention; not critical for a metadata-only package. |
| No `"files"` field | Low | Without `"files"`, `npm publish` packs everything not in `.gitignore` (including `experiments/`, `test-data/`, docs). Adding `"files"` shrinks the tarball. |
| No `package-lock.json` | Informational | Expected since there are no dependencies. |

### 2.2 PowerShell Version Policy

The `engines` field declares `"powershell": ">=5.1"`. While Windows PowerShell 5.1 has no standalone EOL date (it follows the Windows OS lifecycle), Microsoft actively encourages migration to PowerShell 7.x.

| Version | Status | Notes |
|---|---|---|
| Windows PowerShell 5.1 | Supported (tied to Windows OS lifecycle) | No new features; security-only fixes. |
| PowerShell 7.4 LTS | Supported until Nov 10, 2026 | Current LTS. |
| PowerShell 7.5 (stable) | Supported until May 12, 2026 | Built on .NET 9. |

**Risk**: The scripts use `pwsh` (PowerShell Core 7+) in shebangs and documentation, yet the `engines` field allows 5.1. Windows PowerShell 5.1 uses the `powershell.exe` binary, not `pwsh`. If a user runs on PowerShell 5.1 they may encounter subtle incompatibilities.

**Recommendation**: Align the documented requirement with actual usage. If `pwsh` is required, update the floor to `>=7.2` (oldest LTS that was widely adopted) or `>=7.4` (current LTS).

### 2.3 Git Version — Security Vulnerabilities

Git is used throughout the codebase but no minimum version is enforced. Recent high-severity CVEs affect older Git versions:

| CVE | Fixed In | Severity | Description |
|---|---|---|---|
| CVE-2025-48384 | 2.50.1 | High | Arbitrary code execution via broken config quoting in submodule paths. |
| CVE-2025-48385 | 2.50.1 | High | Protocol injection via `bundle-uri` allows writing bundles to arbitrary locations. |
| CVE-2025-48386 | 2.50.1 | High (Windows) | Buffer overflow in Wincred credential helper. |
| CVE-2024-50349 | 2.48.1 | Medium | Credential theft via ANSI escape sequence injection in URL hostnames. |
| CVE-2024-52006 | 2.48.1 | Medium | Credential protocol injection via carriage returns in URLs. |

**Risk**: GitZoom is a Git workflow accelerator — users trust it to interact safely with Git. Running on Git < 2.48.1 exposes users to credential-theft attacks; < 2.50.1 exposes them to code execution via submodules.

**Recommendation**: Add a runtime Git version check in `install-gitzoom.ps1` and `zoom.ps1` that warns (or errors) when Git < 2.48.1 is detected. Document Git >= 2.48.1 as the minimum supported version.

### 2.4 Missing Tooling

| Missing Component | Priority | Rationale |
|---|---|---|
| CI/CD pipeline (GitHub Actions) | Medium | No automated testing or linting. A basic workflow could run the PowerShell scripts to catch regressions. |
| Dependabot / Renovate | Low | Not actionable today (no npm deps), but useful if dependencies are added later. |
| `.npmrc` or publish config | Low | Protects against accidental `npm publish` without auth / scope. |
| `"files"` whitelist in `package.json` | Low | Prevents publishing test/experiment files to npm. |

---

## 3. Proposed Update Plan

Updates are ordered by priority (highest confidence, lowest risk first).

### Tier 1 — Safe, No Breaking Changes

These changes are metadata-only and do not affect runtime behavior.

| # | Change | File(s) | Risk | Breaking? |
|---|---|---|---|---|
| 1a | Add `"files"` field to `package.json` listing only the files needed for installation: `["scripts/", "configs/", "install-gitzoom.ps1", "LICENSE", "README.md"]` | `package.json` | None | No |
| 1b | Add `"engines": { "node": ">=16" }` alongside the existing powershell hint | `package.json` | None | No |
| 1c | Document minimum Git version (>= 2.48.1) in `README.md` and `docs/INSTALLATION.md` | `README.md`, `docs/INSTALLATION.md` | None | No |

### Tier 2 — Low Risk, Minor Behavior Change

| # | Change | File(s) | Risk | Breaking? |
|---|---|---|---|---|
| 2a | Add a Git version check to `install-gitzoom.ps1` that emits a **warning** (not error) when Git < 2.48.1 is detected | `install-gitzoom.ps1` | Low — warning only, does not block install | No |
| 2b | Add a Git version check to `scripts/zoom.ps1` that emits a one-time warning per session when Git < 2.48.1 is detected | `scripts/zoom.ps1` | Low — warning only | No |

### Tier 3 — Medium Risk, Potentially Breaking

| # | Change | File(s) | Risk | Breaking? |
|---|---|---|---|---|
| 3a | Update `engines.powershell` from `>=5.1` to `>=7.2` to reflect actual `pwsh` requirement | `package.json` | Medium — users on Windows PowerShell 5.1 would see the requirement change. Note: npm ignores this field, so the practical impact is documentation-only. | Soft break (docs) |
| 3b | Add a PowerShell version check to `install-gitzoom.ps1` that warns when `$PSVersionTable.PSVersion.Major -lt 7` | `install-gitzoom.ps1` | Low-Medium — warns users on 5.1 that they may hit issues | No |

### Tier 4 — Infrastructure Improvements (No Code Risk)

| # | Change | File(s) | Risk | Breaking? |
|---|---|---|---|---|
| 4a | Add a GitHub Actions workflow (`.github/workflows/validate.yml`) that runs `pwsh -File scripts/zoom.ps1 -message "CI test"` on push | New file | None — additive, does not change existing behavior | No |
| 4b | Add `.github/dependabot.yml` configured for GitHub Actions version updates | New file | None — only monitors Actions versions, not relevant until 4a is done | No |

---

## 4. What's NOT Needed

| Action | Why Not |
|---|---|
| `npm audit` | Zero npm dependencies — nothing to audit. |
| `npm update` / `npm outdated` | No lockfile, no packages to update. |
| Migrate to a different package manager | No benefit with zero dependencies. |
| Add `devDependencies` (eslint, prettier, etc.) | PowerShell scripts; JS tooling doesn't apply. Consider PSScriptAnalyzer if PS linting is desired. |

---

## 5. Recommended Execution Order

```
1a → 1b → 1c → 2a → 2b → 3a → 3b → 4a → 4b
```

Tiers 1-2 can be shipped in a single PR with high confidence. Tier 3 should be a separate PR for review. Tier 4 is independent infrastructure work.
