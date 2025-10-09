# Windows-Specific Test Data Generator for GitZoom
# Advanced scenarios for Windows file system, git operations, and edge cases

param(
    [string]$ScenarioType = "all",
    [string]$DataScale = "medium", # small, medium, large, extreme
    [switch]$IncludeEdgeCases,
    [switch]$CleanupFirst,
    [string]$OutputPath = "test-data"
)

Write-Host "🎭 GitZoom Windows Test Data Generator" -ForegroundColor Magenta
Write-Host "=" * 50 -ForegroundColor Gray
Write-Host "Focus: Windows-specific scenarios and edge cases" -ForegroundColor Yellow
Write-Host ""

# Scale definitions
$scales = @{
    small = @{ FileCount = 10; FileSize = 1KB; RepoDepth = 3 }
    medium = @{ FileCount = 50; FileSize = 10KB; RepoDepth = 5 }
    large = @{ FileCount = 200; FileSize = 100KB; RepoDepth = 8 }
    extreme = @{ FileCount = 1000; FileSize = 1MB; RepoDepth = 12 }
}

$currentScale = $scales[$DataScale]

# Ensure output directory exists
if ($CleanupFirst -and (Test-Path $OutputPath)) {
    Write-Host "🧹 Cleaning up existing test data..." -ForegroundColor Yellow
    Remove-Item -Path $OutputPath -Recurse -Force
}

if (!(Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

function New-TestFile {
    param(
        [string]$Path,
        [string]$Content,
        [string]$Encoding = "UTF8",
        [hashtable]$Attributes = @{}
    )
    
    # Create directory if needed
    $directory = Split-Path $Path -Parent
    if ($directory -and !(Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    
    # Write content
    $Content | Out-File -FilePath $Path -Encoding $Encoding
    
    # Set Windows-specific attributes
    foreach ($attr in $Attributes.GetEnumerator()) {
        Set-ItemProperty -Path $Path -Name $attr.Key -Value $attr.Value
    }
}

function Generate-WindowsPathScenarios {
    Write-Host "📁 Generating Windows Path Scenarios..." -ForegroundColor Cyan
    
    $pathTests = @(
        # Long paths
        @{
            Name = "long-path-test"
            Path = "$OutputPath/" + ("long-directory-name" * 5) + "/deeply/nested/structure/file.txt"
            Content = "Testing long path handling on Windows"
        },
        
        # Special characters in paths
        @{
            Name = "special-chars"
            Path = "$OutputPath/special-chars/file with spaces & symbols [test].txt"
            Content = "Testing special characters in Windows paths"
        },
        
        # Unicode paths
        @{
            Name = "unicode-path"
            Path = "$OutputPath/unicode/测试文件/tést-fīlė.txt"
            Content = "Testing Unicode path support on Windows"
        },
        
        # Reserved names (should handle gracefully)
        @{
            Name = "reserved-names"
            Path = "$OutputPath/reserved/not-CON.txt"
            Content = "Testing near-reserved names (CON, PRN, AUX, etc.)"
        },
        
        # Case sensitivity tests
        @{
            Name = "case-sensitivity-lower"
            Path = "$OutputPath/case-test/lowercase.txt"
            Content = "Testing Windows case insensitivity - lowercase"
        },
        @{
            Name = "case-sensitivity-upper"
            Path = "$OutputPath/case-test/UPPERCASE.txt"
            Content = "Testing Windows case insensitivity - uppercase"
        }
    )
    
    foreach ($test in $pathTests) {
        try {
            New-TestFile -Path $test.Path -Content $test.Content
            Write-Host "✅ Created: $($test.Name)" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠️ Failed to create $($test.Name): $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

function Generate-WindowsFileAttributes {
    Write-Host "🏷️ Generating Windows File Attribute Tests..." -ForegroundColor Cyan
    
    $attributeTests = @(
        @{
            Name = "readonly-file.txt"
            Content = "This file is read-only"
            Attributes = @{ Attributes = "ReadOnly" }
        },
        @{
            Name = "hidden-file.txt"
            Content = "This file is hidden"
            Attributes = @{ Attributes = "Hidden" }
        },
        @{
            Name = "system-file.txt"
            Content = "This file has system attribute"
            Attributes = @{ Attributes = "System" }
        },
        @{
            Name = "archive-file.txt"
            Content = "This file has archive attribute"
            Attributes = @{ Attributes = "Archive" }
        },
        @{
            Name = "multiple-attrs.txt"
            Content = "This file has multiple attributes"
            Attributes = @{ Attributes = "ReadOnly,Hidden,Archive" }
        }
    )
    
    $attrPath = "$OutputPath/file-attributes"
    
    foreach ($test in $attributeTests) {
        try {
            $filePath = "$attrPath/$($test.Name)"
            New-TestFile -Path $filePath -Content $test.Content -Attributes $test.Attributes
            Write-Host "✅ Created attribute test: $($test.Name)" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠️ Failed to create attribute test $($test.Name): $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

function Generate-NTFSFeatures {
    Write-Host "💾 Generating NTFS Feature Tests..." -ForegroundColor Cyan
    
    try {
        # Test alternate data streams
        $streamFile = "$OutputPath/ntfs/alternate-streams.txt"
        New-TestFile -Path $streamFile -Content "Main file content"
        
        # Add alternate streams
        "Hidden stream 1" | Out-File "$streamFile`:stream1" -Encoding UTF8
        "Hidden stream 2" | Out-File "$streamFile`:stream2" -Encoding UTF8
        "Metadata stream" | Out-File "$streamFile`:metadata" -Encoding UTF8
        
        Write-Host "✅ Created NTFS alternate data streams" -ForegroundColor Green
        
        # Test file compression
        $compressFile = "$OutputPath/ntfs/compressed-file.txt"
        $largeContent = "Large content for compression test.`n" * 1000
        New-TestFile -Path $compressFile -Content $largeContent
        
        # Try to enable compression
        try {
            $folder = Split-Path $compressFile -Parent
            compact.exe /C /S:$folder /Q 2>$null
            Write-Host "✅ Enabled NTFS compression" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠️ Could not enable NTFS compression: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        # Test hard links
        $originalFile = "$OutputPath/ntfs/original.txt"
        $hardLinkFile = "$OutputPath/ntfs/hardlink.txt"
        
        New-TestFile -Path $originalFile -Content "Shared content for hard link test"
        
        try {
            # Create hard link using fsutil
            $result = cmd.exe /c "fsutil hardlink create `"$hardLinkFile`" `"$originalFile`"" 2>$null
            if (Test-Path $hardLinkFile) {
                Write-Host "✅ Created NTFS hard link" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "⚠️ Could not create hard link: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
    }
    catch {
        Write-Host "⚠️ NTFS feature test failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Generate-GitLineEndingScenarios {
    Write-Host "🔄 Generating Git Line Ending Scenarios..." -ForegroundColor Cyan
    
    $lineEndingTests = @(
        @{
            Name = "crlf-file.txt"
            Content = "Line 1`r`nLine 2`r`nLine 3`r`n"
            Description = "Windows CRLF line endings"
        },
        @{
            Name = "lf-file.txt"
            Content = "Line 1`nLine 2`nLine 3`n"
            Description = "Unix LF line endings"
        },
        @{
            Name = "cr-file.txt"
            Content = "Line 1`rLine 2`rLine 3`r"
            Description = "Old Mac CR line endings"
        },
        @{
            Name = "mixed-endings.txt"
            Content = "Line 1`r`nLine 2`nLine 3`rLine 4`r`n"
            Description = "Mixed line endings"
        }
    )
    
    $lineEndingPath = "$OutputPath/line-endings"
    
    foreach ($test in $lineEndingTests) {
        $filePath = "$lineEndingPath/$($test.Name)"
        # Use specific encoding to preserve line endings
        [System.IO.File]::WriteAllText($filePath, $test.Content, [System.Text.Encoding]::UTF8)
        Write-Host "✅ Created line ending test: $($test.Name) - $($test.Description)" -ForegroundColor Green
    }
    
    # Create .gitattributes file for line ending testing
    $gitattributes = @"
# Line ending test configurations
*.txt text
crlf-file.txt text eol=crlf
lf-file.txt text eol=lf
mixed-endings.txt text eol=crlf
"@
    
    $gitattributes | Out-File "$lineEndingPath/.gitattributes" -Encoding ASCII
    Write-Host "✅ Created .gitattributes for line ending tests" -ForegroundColor Green
}

function Generate-LargeFileScenarios {
    Write-Host "📏 Generating Large File Scenarios..." -ForegroundColor Cyan
    
    $largePath = "$OutputPath/large-files"
    
    # Generate files of different sizes
    $fileSizes = @(
        @{ Name = "small.bin"; Size = 1KB; Description = "1KB file" },
        @{ Name = "medium.bin"; Size = 1MB; Description = "1MB file" },
        @{ Name = "large.bin"; Size = 10MB; Description = "10MB file" }
    )
    
    if ($currentScale.FileSize -ge 100KB) {
        $fileSizes += @{ Name = "very-large.bin"; Size = 100MB; Description = "100MB file" }
    }
    
    foreach ($fileTest in $fileSizes) {
        try {
            $filePath = "$largePath/$($fileTest.Name)"
            
            # Create file with random data
            $buffer = New-Object byte[] 8192
            $random = New-Object System.Random
            $random.NextBytes($buffer)
            
            $stream = [System.IO.File]::Create($filePath)
            $bytesWritten = 0
            
            while ($bytesWritten -lt $fileTest.Size) {
                $bytesToWrite = [Math]::Min(8192, $fileTest.Size - $bytesWritten)
                $stream.Write($buffer, 0, $bytesToWrite)
                $bytesWritten += $bytesToWrite
            }
            
            $stream.Close()
            
            Write-Host "✅ Created large file: $($fileTest.Description)" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠️ Failed to create large file $($fileTest.Name): $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

function Generate-PerformanceTestData {
    Write-Host "⚡ Generating Performance Test Data..." -ForegroundColor Cyan
    
    $perfPath = "$OutputPath/performance"
    
    # Generate many small files
    Write-Host "Creating $($currentScale.FileCount) small files..." -ForegroundColor Gray
    1..$currentScale.FileCount | ForEach-Object {
        $content = @"
// Performance test file $_
// Generated: $(Get-Date)
// Test iteration: $_

function performanceTest$_() {
    const data = {
        id: $_,
        timestamp: '$(Get-Date)',
        iteration: $_,
        randomValue: Math.random()
    };
    
    // Simulate some processing
    for (let i = 0; i < 100; i++) {
        data.processedValue = i * $_;
    }
    
    return data;
}

module.exports = performanceTest$_;
"@
        
        $filePath = "$perfPath/batch-$([math]::Floor(($_ - 1) / 20))/perf-test-$_.js"
        New-TestFile -Path $filePath -Content $content
        
        if ($_ % 50 -eq 0) {
            Write-Host "  Progress: $_ / $($currentScale.FileCount) files" -ForegroundColor DarkGray
        }
    }
    
    Write-Host "✅ Created $($currentScale.FileCount) performance test files" -ForegroundColor Green
}

function Generate-EdgeCaseScenarios {
    if (-not $IncludeEdgeCases) { return }
    
    Write-Host "⚠️ Generating Edge Case Scenarios..." -ForegroundColor Cyan
    
    $edgePath = "$OutputPath/edge-cases"
    
    # Empty files
    New-TestFile -Path "$edgePath/empty-file.txt" -Content ""
    
    # Files with only whitespace
    New-TestFile -Path "$edgePath/whitespace-only.txt" -Content "   `t  `n  `r`n  "
    
    # Binary files
    $binaryData = [byte[]](0..255)
    [System.IO.File]::WriteAllBytes("$edgePath/binary-data.bin", $binaryData)
    
    # Very long single line
    $longLine = "This is a very long line " * 1000
    New-TestFile -Path "$edgePath/long-single-line.txt" -Content $longLine
    
    # Many short lines
    $manyLines = (1..10000 | ForEach-Object { "Line $_" }) -join "`n"
    New-TestFile -Path "$edgePath/many-short-lines.txt" -Content $manyLines
    
    # Non-ASCII content
    $nonAscii = "Ñoñó test 测试 тест ñoño émojis: 🚀🧪⚡💾🔄"
    New-TestFile -Path "$edgePath/non-ascii.txt" -Content $nonAscii -Encoding "UTF8"
    
    Write-Host "✅ Created edge case scenarios" -ForegroundColor Green
}

function Generate-TestReport {
    Write-Host "📊 Generating Test Data Report..." -ForegroundColor Cyan
    
    $report = @{
        GeneratedAt = Get-Date
        Scale = $DataScale
        ScenarioType = $ScenarioType
        IncludedEdgeCases = $IncludeEdgeCases.IsPresent
        Configuration = $currentScale
        Statistics = @{
            TotalFiles = (Get-ChildItem -Path $OutputPath -Recurse -File).Count
            TotalDirectories = (Get-ChildItem -Path $OutputPath -Recurse -Directory).Count
            TotalSize = [math]::Round((Get-ChildItem -Path $OutputPath -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
        }
        CreatedScenarios = @()
    }
    
    # Add scenario information
    if ($ScenarioType -eq "all" -or $ScenarioType -eq "paths") {
        $report.CreatedScenarios += "Windows path scenarios"
    }
    if ($ScenarioType -eq "all" -or $ScenarioType -eq "attributes") {
        $report.CreatedScenarios += "File attribute tests"
    }
    if ($ScenarioType -eq "all" -or $ScenarioType -eq "ntfs") {
        $report.CreatedScenarios += "NTFS feature tests"
    }
    if ($ScenarioType -eq "all" -or $ScenarioType -eq "git") {
        $report.CreatedScenarios += "Git line ending scenarios"
    }
    if ($ScenarioType -eq "all" -or $ScenarioType -eq "large") {
        $report.CreatedScenarios += "Large file scenarios"
    }
    if ($ScenarioType -eq "all" -or $ScenarioType -eq "performance") {
        $report.CreatedScenarios += "Performance test data"
    }
    if ($IncludeEdgeCases) {
        $report.CreatedScenarios += "Edge case scenarios"
    }
    
    $reportFile = "$OutputPath/test-data-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $report | ConvertTo-Json -Depth 5 | Out-File $reportFile -Encoding UTF8
    
    Write-Host "📋 Test data report saved: $reportFile" -ForegroundColor Green
    Write-Host "📊 Total files created: $($report.Statistics.TotalFiles)" -ForegroundColor White
    Write-Host "📁 Total directories: $($report.Statistics.TotalDirectories)" -ForegroundColor White
    Write-Host "💾 Total size: $($report.Statistics.TotalSize) MB" -ForegroundColor White
}

# Main execution
Write-Host "Generating Windows test data..." -ForegroundColor Yellow
Write-Host "Scale: $DataScale | Scenario: $ScenarioType | Edge Cases: $($IncludeEdgeCases.IsPresent)" -ForegroundColor Gray
Write-Host ""

# Generate scenarios based on parameters
switch ($ScenarioType.ToLower()) {
    "paths" { Generate-WindowsPathScenarios }
    "attributes" { Generate-WindowsFileAttributes }
    "ntfs" { Generate-NTFSFeatures }
    "git" { Generate-GitLineEndingScenarios }
    "large" { Generate-LargeFileScenarios }
    "performance" { Generate-PerformanceTestData }
    "all" {
        Generate-WindowsPathScenarios
        Generate-WindowsFileAttributes
        Generate-NTFSFeatures
        Generate-GitLineEndingScenarios
        Generate-LargeFileScenarios
        Generate-PerformanceTestData
    }
    default {
        Write-Host "Unknown scenario type: $ScenarioType" -ForegroundColor Red
        Write-Host "Available scenarios: paths, attributes, ntfs, git, large, performance, all" -ForegroundColor Yellow
        exit 1
    }
}

if ($IncludeEdgeCases) {
    Generate-EdgeCaseScenarios
}

Generate-TestReport

Write-Host ""
Write-Host "🎉 Windows Test Data Generation Complete!" -ForegroundColor Magenta