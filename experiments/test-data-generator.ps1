# Test Data Generator for GitZoom Experiments
param(
    [string]$DataType = "all",
    [int]$FileCount = 10,
    [switch]$CleanUp
)

Write-Host "🎭 GitZoom Test Data Generator" -ForegroundColor Magenta
Write-Host "=" * 40 -ForegroundColor Gray

# Ensure test-data directory exists
$testDataPath = "test-data"
if (!(Test-Path $testDataPath)) {
    New-Item -ItemType Directory -Path $testDataPath -Force
    Write-Host "📁 Created test-data directory" -ForegroundColor Green
}

function Generate-SmallFiles {
    param([int]$Count = 10)
    
    Write-Host "📝 Generating $Count small files..." -ForegroundColor Cyan
    
    1..$Count | ForEach-Object {
        $content = @"
// Test File $_
// Generated: $(Get-Date)
// Size: Small (~500 bytes)

function testFunction$_() {
    console.log('This is test function $_');
    const data = {
        id: $_,
        name: 'Test Item $_',
        timestamp: '$(Get-Date)',
        active: true
    };
    return data;
}

export { testFunction$_ };
"@
        $content | Out-File "$testDataPath/small-test-$_.js" -Encoding UTF8
    }
    
    Write-Host "✅ Generated $Count small JavaScript files" -ForegroundColor Green
}

function Generate-MediumFiles {
    param([int]$Count = 5)
    
    Write-Host "📄 Generating $Count medium files..." -ForegroundColor Cyan
    
    1..$Count | ForEach-Object {
        $content = @"
# Medium Test File $_
# Generated: $(Get-Date)
# Size: Medium (~5KB)

## Overview
This is a medium-sized test file used for GitZoom performance testing.

## Test Data
$((1..50 | ForEach-Object { "Line $_ with some test content that makes this file larger" }) -join "`n")

## Code Examples
``````javascript
// Example $_
function complexFunction$_() {
    const largeArray = [];
    for (let i = 0; i < 100; i++) {
        largeArray.push({
            index: i,
            value: Math.random(),
            timestamp: new Date(),
            nested: {
                property1: 'value' + i,
                property2: i * 2,
                property3: Boolean(i % 2)
            }
        });
    }
    return largeArray;
}
``````

## More Content
$((1..30 | ForEach-Object { "Additional line $_ to increase file size for testing purposes." }) -join "`n")
"@
        $content | Out-File "$testDataPath/medium-test-$_.md" -Encoding UTF8
    }
    
    Write-Host "✅ Generated $Count medium Markdown files" -ForegroundColor Green
}

function Generate-LargeFiles {
    param([int]$Count = 2)
    
    Write-Host "📦 Generating $Count large files..." -ForegroundColor Cyan
    
    1..$Count | ForEach-Object {
        $content = @"
{
  "testFile": $_,
  "generated": "$(Get-Date)",
  "size": "large",
  "data": [
$((1..1000 | ForEach-Object { 
    "    {`n      `"id`": $_,`n      `"name`": `"Test Item $_`",`n      `"description`": `"Large test data item with description $_`",`n      `"timestamp`": `"$(Get-Date)`",`n      `"metadata`": {`n        `"category`": `"test`",`n        `"priority`": $(Get-Random -Minimum 1 -Maximum 6),`n        `"tags`": [`"tag1`", `"tag2`", `"tag3`"]`n      }`n    }" + $(if ($_ -lt 1000) { "," } else { "" })
}) -join "`n")
  ]
}
"@
        $content | Out-File "$testDataPath/large-test-$_.json" -Encoding UTF8
    }
    
    Write-Host "✅ Generated $Count large JSON files" -ForegroundColor Green
}

function Generate-BinaryFiles {
    param([int]$Count = 3)
    
    Write-Host "🖼️ Generating $Count binary test files..." -ForegroundColor Cyan
    
    # Generate simple bitmap-like binary files
    1..$Count | ForEach-Object {
        $bytes = New-Object byte[] 10240  # 10KB binary file
        (New-Object Random).NextBytes($bytes)
        [System.IO.File]::WriteAllBytes("$testDataPath/binary-test-$_.dat", $bytes)
    }
    
    Write-Host "✅ Generated $Count binary files" -ForegroundColor Green
}

function Generate-NestedStructure {
    Write-Host "📁 Generating nested directory structure..." -ForegroundColor Cyan
    
    $folders = @("components", "utils", "tests", "docs", "assets")
    
    foreach ($folder in $folders) {
        $folderPath = "$testDataPath/nested/$folder"
        if (!(Test-Path $folderPath)) {
            New-Item -ItemType Directory -Path $folderPath -Force | Out-Null
        }
        
        # Create files in each folder
        1..3 | ForEach-Object {
            $content = @"
// File $_ in $folder
// Path: $folderPath
// Generated: $(Get-Date)

export const ${folder}Config$_ = {
    name: '$folder-item-$_',
    version: '1.0.$_',
    enabled: true,
    settings: {
        debug: false,
        verbose: true,
        timeout: $(Get-Random -Minimum 1000 -Maximum 5000)
    }
};
"@
            $content | Out-File "$folderPath/${folder}-item-$_.js" -Encoding UTF8
        }
    }
    
    Write-Host "✅ Generated nested directory structure with files" -ForegroundColor Green
}

function Generate-RealisticGitScenarios {
    Write-Host "🔀 Generating realistic Git scenario files..." -ForegroundColor Cyan
    
    # Simulate common development scenarios
    
    # 1. Bug fix scenario
    $bugFixContent = @"
// BUG FIX: Fixed null pointer exception
// Before: function could crash with undefined input
// After: proper input validation

function processData(input) {
    // FIXED: Added null check
    if (!input || typeof input !== 'object') {
        throw new Error('Invalid input: expected object, got ' + typeof input);
    }
    
    return {
        processed: true,
        timestamp: new Date(),
        data: input
    };
}

// Test cases added
const testCases = [
    { input: { test: 'data' }, expected: true },
    { input: null, expected: 'error' },
    { input: undefined, expected: 'error' }
];
"@
    $bugFixContent | Out-File "$testDataPath/bugfix-example.js" -Encoding UTF8
    
    # 2. Feature addition
    $featureContent = @"
# NEW FEATURE: User Authentication

## Overview
Added comprehensive user authentication system with the following features:

- JWT token-based authentication
- Password hashing with bcrypt
- Rate limiting for login attempts
- Session management
- Role-based access control

## Implementation
- \`auth.js\`: Core authentication logic
- \`middleware.js\`: Authentication middleware
- \`routes.js\`: Authentication routes
- \`tests.js\`: Comprehensive test suite

## Security Features
1. Password complexity requirements
2. Account lockout after failed attempts
3. Secure session cookies
4. CSRF protection
5. Input sanitization

## Usage Example
\`\`\`javascript
const auth = require('./auth');
const user = await auth.login(email, password);
\`\`\`
"@
    $featureContent | Out-File "$testDataPath/feature-auth.md" -Encoding UTF8
    
    # 3. Refactoring scenario
    $refactorContent = @"
// REFACTOR: Extracted utility functions for better maintainability
// Moved common functions to utils module
// Improved code organization and reusability

const { formatDate, validateEmail, sanitizeInput } = require('./utils');

class UserService {
    constructor(database) {
        this.db = database;
    }
    
    async createUser(userData) {
        // REFACTORED: Using extracted validation
        const email = validateEmail(userData.email);
        const sanitized = sanitizeInput(userData);
        
        return await this.db.users.create({
            ...sanitized,
            email,
            createdAt: formatDate(new Date()),
            updatedAt: formatDate(new Date())
        });
    }
    
    async updateUser(id, updates) {
        // REFACTORED: Consistent date formatting
        const sanitized = sanitizeInput(updates);
        return await this.db.users.update(id, {
            ...sanitized,
            updatedAt: formatDate(new Date())
        });
    }
}

module.exports = UserService;
"@
    $refactorContent | Out-File "$testDataPath/refactor-example.js" -Encoding UTF8
    
    Write-Host "✅ Generated realistic development scenario files" -ForegroundColor Green
}

function Clean-TestData {
    Write-Host "🧹 Cleaning up test data..." -ForegroundColor Yellow
    
    if (Test-Path $testDataPath) {
        Remove-Item $testDataPath -Recurse -Force
        Write-Host "✅ Test data cleaned up" -ForegroundColor Green
    } else {
        Write-Host "ℹ️ No test data to clean" -ForegroundColor Blue
    }
}

# Main execution
if ($CleanUp) {
    Clean-TestData
    exit 0
}

Write-Host "🚀 Generating test data..." -ForegroundColor Yellow

switch ($DataType.ToLower()) {
    "small" { Generate-SmallFiles -Count $FileCount }
    "medium" { Generate-MediumFiles -Count $FileCount }
    "large" { Generate-LargeFiles -Count $FileCount }
    "binary" { Generate-BinaryFiles -Count $FileCount }
    "nested" { Generate-NestedStructure }
    "scenarios" { Generate-RealisticGitScenarios }
    "all" {
        Generate-SmallFiles -Count 10
        Generate-MediumFiles -Count 5
        Generate-LargeFiles -Count 2
        Generate-BinaryFiles -Count 3
        Generate-NestedStructure
        Generate-RealisticGitScenarios
    }
}

# Show summary
Write-Host "`n📊 Test Data Summary:" -ForegroundColor Magenta
if (Test-Path $testDataPath) {
    $files = Get-ChildItem $testDataPath -Recurse -File
    $totalSize = ($files | Measure-Object Length -Sum).Sum
    
    Write-Host "  Total Files: $($files.Count)"
    Write-Host "  Total Size: $([math]::Round($totalSize / 1KB, 2)) KB"
    Write-Host "  Location: $((Get-Item $testDataPath).FullName)"
    
    # File type breakdown
    $extensions = $files | Group-Object Extension | Sort-Object Count -Descending
    Write-Host "`n  File Types:"
    $extensions | ForEach-Object {
        $ext = if ($_.Name) { $_.Name } else { "(no extension)" }
        Write-Host "    $ext`: $($_.Count) files"
    }
}

Write-Host "`n✨ Test data generation completed!" -ForegroundColor Green
Write-Host "💡 Next steps:" -ForegroundColor Cyan
Write-Host "  1. Run performance benchmarks: .\experiments\performance-benchmark.ps1" -ForegroundColor White
Write-Host "  2. Test GitZoom lightning push: zoom 'test with generated data'" -ForegroundColor White
Write-Host "  3. Analyze results and optimize!" -ForegroundColor White