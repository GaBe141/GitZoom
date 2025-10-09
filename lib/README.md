# GitZoom Library

This directory contains the core PowerShell modules that make up the GitZoom library.

## Module Structure

### Core Modules

- **GitZoom.psm1** - Main module file that imports all components and sets up the module
- **GitZoom.psd1** - Module manifest with metadata, dependencies, and exported functions

### Component Modules

- **Configuration.ps1** - Configuration management (load, save, validate, reset)
- **Performance.ps1** - Performance measurement and optimization tracking
- **Staging.ps1** - Intelligent file staging with batch processing
- **Commit.ps1** - Smart commit operations with message optimization
- **ErrorHandling.ps1** - Error handling framework and recovery mechanisms
- **Installation.ps1** - Installation, update, and environment setup utilities
- **Utilities.ps1** - Common helper functions (formatting, validation, Git operations)

## Architecture

GitZoom uses a modular architecture where each component is a separate PowerShell script:

```
GitZoom.psd1 (Manifest)
    ↓
GitZoom.psm1 (Main Module)
    ├── Configuration.ps1
    ├── Performance.ps1
    ├── Staging.ps1
    ├── Commit.ps1
    ├── ErrorHandling.ps1
    ├── Installation.ps1
    └── Utilities.ps1
```

## Key Features

### Configuration Management
- JSON-based configuration storage
- Environment detection and auto-configuration
- Validation and migration support

### Performance Optimization
- Operation timing and metrics
- Windows-specific optimizations
- Git configuration tuning

### Intelligent Staging
- File analysis and categorization
- Batch processing strategies
- Binary file detection

### Smart Commits
- Conventional commit format support
- Automatic scope detection
- Message optimization

## Development Guidelines

### Adding New Functions

1. Add function to appropriate module file
2. Update the FunctionsToExport list in `GitZoom.psd1`
3. Add tests to `../tests/`
4. Document in function help comments

### Code Standards

- Use approved PowerShell verbs
- Include proper help documentation
- Handle errors gracefully
- Support -WhatIf and -Verbose where appropriate
- Follow PowerShell naming conventions

### Module Loading

Functions are exported through the manifest system:
- Individual modules don't use Export-ModuleMember
- All exports are defined in GitZoom.psd1
- Main module (GitZoom.psm1) dot-sources component scripts

## Version Information

- **Current Version:** 1.0.0
- **PowerShell Version Required:** 5.1+
- **Git Version Required:** 2.0+
- **Platform:** Windows (optimized)
