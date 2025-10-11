# Integration Testing for GitZoom

This directory contains comprehensive integration tests that validate GitZoom against real-world Git scenarios.

## Test Suites

### 1. Large Repository Tests (`Test-LargeRepository.Tests.ps1`)
- Tests with 1000+ files
- Multi-level directory structures
- Large file handling (>10MB)
- Performance benchmarks

### 2. Binary File Tests (`Test-BinaryFiles.Tests.ps1`)
- Image files (PNG, JPG, GIF)
- Compiled binaries (EXE, DLL)
- Archive files (ZIP, 7z)
- Office documents (DOCX, XLSX)

### 3. Submodule Tests (`Test-Submodules.Tests.ps1`)
- Repositories with submodules
- Nested submodules
- Submodule updates
- Submodule initialization

### 4. Branch Strategy Tests (`Test-BranchStrategies.Tests.ps1`)
- GitFlow workflow
- Trunk-based development
- Feature branching
- Release branching

### 5. Conflict Resolution Tests (`Test-ConflictResolution.Tests.ps1`)
- Merge conflicts
- Rebase conflicts
- Cherry-pick conflicts
- Conflict detection and reporting

### 6. Edge Case Tests (`Test-EdgeCases.Tests.ps1`)
- Empty repositories
- Repositories with no commits
- Detached HEAD states
- Bare repositories
- Corrupted repositories

## Running Integration Tests

```powershell
# Run all integration tests
./Run-IntegrationTests.ps1

# Run specific test suite
Invoke-Pester ./Integration/Test-LargeRepository.Tests.ps1 -Output Detailed

# Run with performance metrics
./Run-IntegrationTests.ps1 -IncludePerformance
```

## Test Data Generation

Integration tests use the test data generator to create realistic scenarios:

```powershell
# Generate large repository test data
./scripts/Generate-IntegrationTestData.ps1 -Scenario LargeRepository

# Generate all test scenarios
./scripts/Generate-IntegrationTestData.ps1 -All
```

## CI Integration

Integration tests run on:
- Pull requests (subset)
- Main branch commits (full suite)
- Nightly builds (extended suite with performance)
