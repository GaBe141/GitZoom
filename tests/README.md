# GitZoom Test Suite

This directory contains automated tests for the GitZoom PowerShell module.

## Test Files

### BasicValidation.Tests.ps1
Pester 3.x compatible tests that validate core GitZoom functionality:
- Module loading and function exports
- Basic initialization and configuration
- Utility function operations
- Git repository detection

## Running Tests

### Run all tests:
```powershell
cd tests
Invoke-Pester
```

### Run with verbose output:
```powershell
Invoke-Pester -Verbose
```

### Run with code coverage:
```powershell
Invoke-Pester -CodeCoverage ..\lib\*.ps1
```

### Generate test report:
```powershell
Invoke-Pester -OutputFormat NUnitXml -OutputFile TestResults.xml
```

## Test Framework

- **Pester Version:** 3.4.0+ (compatible with Pester 3.x syntax)
- **PowerShell Version:** 5.1+
- **Test Categories:** 
  - Module Loading
  - Basic Functionality
  - Utility Functions

## Test Results

Test results and reports are stored in `../TestResults/` directory.

## Adding New Tests

When adding new tests:
1. Use Pester 3.x compatible syntax
2. Follow the existing test structure
3. Include proper BeforeAll/AfterAll cleanup
4. Test both success and failure scenarios
5. Keep tests isolated and independent

## Known Limitations

- Complex unit tests require migration to Pester 5.x syntax
- Integration tests with real Git operations need separate test repositories
- Performance tests should use dedicated benchmark scripts in `../experiments/`
