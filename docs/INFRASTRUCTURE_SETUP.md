# GitZoom Infrastructure Setup Guide

This guide explains the new CI/CD infrastructure and how to configure it.

## Overview

GitZoom now has a comprehensive CI/CD pipeline with:

✅ **Code Coverage Tracking**
✅ **Release Automation**
✅ **Integration Testing**
✅ **Documentation Site (GitHub Pages)**
✅ **Cross-Platform Testing (Windows/Linux/macOS)**
✅ **Security Scanning**

## Setup Instructions

### 1. GitHub Repository Settings

#### Enable GitHub Pages
1. Go to repository Settings → Pages
2. Source: Deploy from a branch → `gh-pages`
3. The docs will be available at `https://gabe141.github.io/GitZoom/`

#### Add Repository Secrets

For PowerShell Gallery publishing:
1. Get your API key from [PowerShell Gallery](https://www.powershellgallery.com/account/apikeys)
2. Go to Settings → Secrets and variables → Actions
3. Add new repository secret:
   - Name: `PSGALLERY_API_KEY`
   - Value: Your PowerShell Gallery API Key

#### Enable GitHub Actions
1. Go to Settings → Actions → General
2. Allow all actions and reusable workflows
3. Workflow permissions: Read and write permissions

### 2. Workflow Files

The following workflows are now configured:

#### `ci.yml` - Main CI/CD Pipeline
- Runs on: Push to main, test/infrastructure branches; Pull requests
- Jobs:
  - Unit tests with code coverage
  - Mutation testing
  - Performance benchmarks
  - Integration tests
  - Load tests

#### `release.yml` - PowerShell Gallery Publishing
- Runs on: Release published; Manual workflow dispatch
- Jobs:
  - Validate code quality
  - Publish to PowerShell Gallery
  - Generate release notes

**To create a release:**
```bash
# Option 1: Manual workflow dispatch
1. Go to Actions → Release to PowerShell Gallery
2. Click "Run workflow"
3. Enter version (e.g., 1.0.0)

# Option 2: Create GitHub release
1. Go to Releases → Create a new release
2. Tag version (e.g., v1.0.0)
3. Publish release → Workflow triggers automatically
```

#### `docs.yml` - Documentation Deployment
- Runs on: Push to main (when docs change); Manual dispatch
- Automatically builds and deploys documentation to GitHub Pages

#### `cross-platform.yml` - Multi-Platform Testing
- Runs on: Push, Pull requests, Nightly schedule (2 AM UTC)
- Tests GitZoom on Windows, Linux, and macOS
- Provides performance comparison across platforms

#### `security.yml` - Security Scanning
- Runs on: Push, Pull requests, Weekly schedule (Monday 3 AM UTC)
- Scans:
  - PowerShell security rules
  - Hardcoded secrets detection
  - Dependency vulnerabilities
  - Supply chain security
  - Code signing status

### 3. Branch Protection Rules

Recommended settings for `main` branch:

1. Go to Settings → Branches → Add rule
2. Branch name pattern: `main`
3. Enable:
   - ✅ Require a pull request before merging
   - ✅ Require status checks to pass before merging
     - Required checks:
       - `test (windows-latest)`
       - `test-matrix (Windows)`
       - `powershell-security`
   - ✅ Require conversation resolution before merging
   - ✅ Do not allow bypassing the above settings

### 4. Test the Infrastructure

#### Run All Tests Locally
```powershell
# Unit tests with coverage
./tests/Run-AllTests.ps1 -Coverage

# Integration tests
./tests/Integration/Run-IntegrationTests.ps1 -IncludePerformance

# Security scan
Invoke-ScriptAnalyzer -Path ./lib -Recurse -Severity Error,Warning
```

#### Trigger Workflows Manually
1. Go to Actions tab
2. Select workflow (e.g., "Cross-Platform Testing")
3. Click "Run workflow"
4. Choose branch and click "Run workflow"

### 5. Monitor and Maintain

#### View Test Results
- Go to Actions → Select workflow run
- Check "Summary" for overview
- Download artifacts for detailed reports

#### Code Coverage
- Coverage reports are generated automatically
- View in Actions → Artifacts → `coverage-report`
- Upload to Codecov (optional):
  ```yaml
  - uses: codecov/codecov-action@v4
    with:
      files: ./Coverage.xml
  ```

#### Performance Tracking
- Performance metrics saved in artifacts
- Compare across branches and platforms
- Set up performance regression alerts

### 6. Documentation Updates

To update documentation:

1. Edit files in `docs/` directory
2. Push to main branch
3. GitHub Actions automatically deploys to GitHub Pages
4. View at: `https://gabe141.github.io/GitZoom/`

### 7. Security Best Practices

The security workflow checks for:
- ✅ Hardcoded secrets
- ✅ Dangerous PowerShell patterns
- ✅ Vulnerable dependencies
- ✅ Missing .gitignore entries
- ✅ Code signing status

**Weekly security scans** run automatically every Monday at 3 AM UTC.

### 8. Release Process

Full release workflow:

1. **Update version** in `lib/GitZoom.psd1`:
   ```powershell
   ModuleVersion = '1.1.0'
   ```

2. **Update CHANGELOG.md** with changes

3. **Test everything locally**:
   ```powershell
   ./tests/Run-AllTests.ps1 -Coverage
   ./tests/Integration/Run-IntegrationTests.ps1
   ```

4. **Create PR** to main branch

5. **After PR approved and merged**:
   - Go to Releases → Draft a new release
   - Tag: `v1.1.0`
   - Title: `GitZoom v1.1.0`
   - Description: Copy from CHANGELOG.md
   - Publish release

6. **Automatic deployment** to PowerShell Gallery

7. **Verify installation**:
   ```powershell
   Install-Module GitZoom -Force
   Get-Module GitZoom -ListAvailable
   ```

## Troubleshooting

### Workflow Fails on PowerShell Gallery Publish
- Verify `PSGALLERY_API_KEY` secret is set correctly
- Check API key hasn't expired
- Ensure module version is incremented

### GitHub Pages Not Updating
- Check Actions → Docs workflow succeeded
- Verify Pages is enabled in Settings
- Clear browser cache

### Cross-Platform Tests Failing
- Check platform-specific code
- Verify file path handling (use `Join-Path`)
- Test locally with PowerShell 7+

### Security Scan False Positives
- Review the specific rule triggered
- Add suppression if legitimate:
  ```powershell
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '')]
  param()
  ```

## Next Steps

- [ ] Set up Codecov integration
- [ ] Add automatic changelog generation
- [ ] Configure semantic versioning
- [ ] Set up performance regression alerts
- [ ] Add badge to README for build status
- [ ] Create contribution guidelines
- [ ] Set up issue templates
- [ ] Add PR template

## Support

For issues with the infrastructure:
1. Check workflow logs in Actions tab
2. Review this guide for setup steps
3. Open an issue on GitHub
4. Tag with `infrastructure` label
