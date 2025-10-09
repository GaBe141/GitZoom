# GitZoom Project Structure

This document describes the organization of the GitZoom project.

## Directory Structure

```
GitZoom/
├── .vscode/              # VS Code workspace settings
├── configs/              # Sample configuration files
├── docs/                 # Documentation files
├── experiments/          # Performance benchmarks and experiments
├── lib/                  # Core PowerShell modules (main library)
├── scripts/              # Utility scripts
├── templates/            # Template files for commits, configs, etc.
├── test-data/            # Sample data for testing
├── tests/                # Automated tests (Pester)
├── TestResults/          # Test output and reports
├── .gitignore           # Git ignore rules
├── gitzoom.code-workspace # VS Code workspace file
├── install-gitzoom.ps1  # Installation script
├── LICENSE              # MIT License
├── package.json         # Node.js package metadata (for VS Code tasks)
├── README.md            # Main project README
└── *.md                 # Various documentation files
```

## Key Directories

### `/lib` - Core Library
The heart of GitZoom containing all PowerShell modules:
- Module manifest (GitZoom.psd1)
- Main module file (GitZoom.psm1)
- Component scripts (Configuration, Performance, Staging, etc.)

See [lib/README.md](lib/README.md) for details.

### `/tests` - Test Suite
Automated tests using Pester framework:
- Basic validation tests
- Unit tests (planned for Pester 5.x migration)
- Integration tests (planned)

See [tests/README.md](tests/README.md) for details.

### `/experiments` - Performance Testing
Benchmarking and optimization experiments:
- Performance comparison scripts
- Optimization experiments
- Test data generators
- Benchmark reports

### `/scripts` - Utility Scripts
Helper scripts for development and operations:
- Lightning push (quick commit and push)
- Development utilities
- Maintenance scripts

### `/docs` - Documentation
Comprehensive documentation:
- API documentation
- User guides
- Architecture documents
- Best practices

### `/templates` - Templates
Reusable templates:
- Commit message templates
- Configuration templates
- Script templates

### `/TestResults` - Test Outputs
Generated test results and reports:
- Test execution reports
- Code coverage reports
- Performance benchmark results
- Continuous test logs

## Configuration Files

### `.vscode/tasks.json`
VS Code tasks for common operations:
- GitZoom: Lightning Push
- GitZoom: Performance Benchmark
- GitZoom: Generate Test Data
- GitZoom: Optimization Experiments

### `gitzoom.code-workspace`
VS Code workspace configuration with project-specific settings.

### `package.json`
Node.js package file for VS Code task management.

## Documentation Files

Located in the root directory:
- **README.md** - Main project overview and getting started
- **LICENSE** - MIT License text
- **GITHUB_SETUP.md** - GitHub repository setup guide
- **PRODUCTION_DEPLOYMENT.md** - Production deployment guide
- **PRODUCTION_SUCCESS.md** - Production validation results
- **PROJECT_SUMMARY.md** - Project technical summary
- **PERFORMANCE_ANALYSIS.md** - Performance analysis results
- **OPTIMIZATION_RESULTS.md** - Optimization experiment results
- **WINDOWS_TESTING_SUMMARY.md** - Windows-specific testing results

## Installation

The `install-gitzoom.ps1` script in the root provides automated installation:
- Copies modules to PowerShell modules directory
- Sets up initial configuration
- Validates Git installation
- Creates necessary directories

## Development Workflow

1. **Code**: Edit files in `/lib`
2. **Test**: Run tests from `/tests`
3. **Benchmark**: Use scripts in `/experiments`
4. **Document**: Update `/docs` and inline help
5. **Package**: Module manifest in `/lib/GitZoom.psd1`

## Git Workflow

The project itself uses GitZoom for development:
- Use `gzinit` to initialize GitZoom in the repository
- Use `gzoom` to check status
- Use `gzadd` for intelligent staging
- Use `gzcommit` for optimized commits

## Build Outputs

Generated files (excluded from Git):
- `/TestResults/` - Test execution results
- `/test-data/` - Generated test data
- Temporary and log files

## Future Structure

Planned additions:
- `/examples` - Example usage scripts
- `/benchmarks` - Standardized benchmark suites
- `/ci` - CI/CD pipeline definitions
- `/dist` - Distribution packages
