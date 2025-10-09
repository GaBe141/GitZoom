# Windows Advanced Testing Suite for GitZoom
# Focus: Windows-specific optimizations and comprehensive testing scenarios

param(
    [string]$TestSuite = "all",
    [int]$Iterations = 3,
    [switch]$Verbose,
    [switch]$GenerateDetailedReport,
    [string]$OutputPath = "test-results"
)

# Import Windows-specific modules
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

Write-Host "🚀 GitZoom Windows Advanced Testing Suite" -ForegroundColor Magenta
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host "Focus: Windows optimizations & comprehensive scenarios" -ForegroundColor Yellow
Write-Host ""

# Global test results
$global:TestResults = @()
$global:TestMetrics = @{
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    TotalDuration = 0
    StartTime = Get-Date
}

# Ensure output directory exists
if (!(Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

function Write-TestHeader {
    param([string]$TestName)
    Write-Host ""
    Write-Host "🧪 $TestName" -ForegroundColor Cyan
    Write-Host ("-" * ($TestName.Length + 3)) -ForegroundColor Gray
}

function Measure-WindowsOperation {
    param(
        [string]$OperationName,
        [scriptblock]$Operation,
        [hashtable]$Context = @{},
        [switch]$ExpectFailure
    )
    
    $global:TestMetrics.TotalTests++
    
    # Windows-specific performance counters
    $process = Get-Process -Id $PID
    $beforeCpu = $process.TotalProcessorTime
    $beforeMemory = [System.GC]::GetTotalMemory($false)
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        $operationResult = & $Operation
        $stopwatch.Stop()
        
        # Measure Windows-specific metrics
        $afterCpu = $process.TotalProcessorTime
        $afterMemory = [System.GC]::GetTotalMemory($false)
        
        $result = [PSCustomObject]@{
            Operation = $OperationName
            Duration = $stopwatch.ElapsedMilliseconds
            Success = $true
            Result = $operationResult
            Context = $Context
            Timestamp = Get-Date
            WindowsMetrics = @{
                CpuTime = ($afterCpu - $beforeCpu).TotalMilliseconds
                MemoryDelta = $afterMemory - $beforeMemory
                ProcessId = $PID
                ThreadCount = (Get-Process -Id $PID).Threads.Count
            }
        }
        
        $global:TestMetrics.PassedTests++
        $statusIcon = if ($ExpectFailure) { "⚠️" } else { "✅" }
        Write-Host "$statusIcon $OperationName`: $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Green
        
        if ($Verbose) {
            Write-Host "   CPU: $([math]::Round(($afterCpu - $beforeCpu).TotalMilliseconds, 2))ms, Memory: $([math]::Round(($afterMemory - $beforeMemory) / 1KB, 2))KB" -ForegroundColor DarkGreen
        }
    }
    catch {
        $stopwatch.Stop()
        
        $result = [PSCustomObject]@{
            Operation = $OperationName
            Duration = $stopwatch.ElapsedMilliseconds
            Success = $false
            Error = $_.Exception.Message
            Context = $Context
            Timestamp = Get-Date
            WindowsMetrics = @{
                CpuTime = 0
                MemoryDelta = 0
                ProcessId = $PID
            }
        }
        
        if ($ExpectFailure) {
            $global:TestMetrics.PassedTests++
            Write-Host "✅ $OperationName`: Expected failure - $($_.Exception.Message)" -ForegroundColor Yellow
        } else {
            $global:TestMetrics.FailedTests++
            Write-Host "❌ $OperationName`: FAILED - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    $global:TestMetrics.TotalDuration += $stopwatch.ElapsedMilliseconds
    $global:TestResults += $result
    return $result
}

function Test-WindowsFileSystemOperations {
    Write-TestHeader "Windows File System Operations"
    
    # Test NTFS-specific features
    Measure-WindowsOperation "NTFS Stream Creation" {
        $testFile = "$OutputPath/ntfs-test.txt"
        "Main content" | Out-File $testFile -Encoding UTF8
        "Alternate stream data" | Out-File "$testFile`:stream1" -Encoding UTF8
        return (Test-Path $testFile)
    } @{ Type = "NTFS"; Feature = "AlternateStreams" }
    
    # Test Windows file attributes
    Measure-WindowsOperation "Windows File Attributes" {
        $testFile = "$OutputPath/attributes-test.txt"
        "Test content" | Out-File $testFile -Encoding UTF8
        Set-ItemProperty -Path $testFile -Name Attributes -Value "ReadOnly,Hidden"
        $attrs = Get-ItemProperty -Path $testFile -Name Attributes
        return $attrs.Attributes
    } @{ Type = "FileSystem"; Feature = "Attributes" }
    
    # Test long path handling (Windows 10+)
    Measure-WindowsOperation "Long Path Handling" {
        $longPath = "$OutputPath/" + ("a" * 200) + ".txt"
        "Long path test" | Out-File $longPath -Encoding UTF8 -ErrorAction Stop
        return (Test-Path $longPath)
    } @{ Type = "FileSystem"; Feature = "LongPaths" }
    
    # Test UNC path operations
    Measure-WindowsOperation "UNC Path Processing" {
        $uncPath = "\\localhost\c$\temp"
        return (Test-Path $uncPath -IsValid)
    } @{ Type = "FileSystem"; Feature = "UNCPaths" }
}

function Test-WindowsGitIntegration {
    Write-TestHeader "Windows Git Integration Tests"
    
    # Test Windows credential manager integration
    Measure-WindowsOperation "Git Credential Manager" {
        $result = git config --get credential.helper
        return $null -ne $result
    } @{ Type = "Git"; Feature = "CredentialManager" }
    
    # Test Windows line ending handling
    Measure-WindowsOperation "CRLF Line Ending Test" {
        $testFile = "$OutputPath/crlf-test.txt"
        "Line 1`r`nLine 2`r`nLine 3" | Out-File $testFile -Encoding UTF8 -NoNewline
        git add $testFile 2>$null
        $status = git status --porcelain $testFile
        return $status
    } @{ Type = "Git"; Feature = "LineEndings" }
    
    # Test Windows file locking behavior
    Measure-WindowsOperation "Windows File Lock Handling" {
        $testFile = "$OutputPath/lock-test.txt"
        "Initial content" | Out-File $testFile -Encoding UTF8
        
        # Simulate file lock
        $fileStream = [System.IO.File]::Open($testFile, 'Open', 'Read', 'None')
        
        try {
            # Try to modify while locked (should handle gracefully)
            git add $testFile 2>$null
            $result = $?
        }
        finally {
            $fileStream.Close()
        }
        
        return $result
    } @{ Type = "Git"; Feature = "FileLocking" }
}

function Test-WindowsPerformanceOptimizations {
    Write-TestHeader "Windows Performance Optimization Tests"
    
    # Test parallel operations using Windows job objects
    Measure-WindowsOperation "Parallel File Processing" {
        $files = 1..10 | ForEach-Object { "$OutputPath/parallel-$_.txt" }
        
        # Create files in parallel using Windows runspaces
        $runspaces = @()
        $runspacePool = [runspacefactory]::CreateRunspacePool(1, 5)
        $runspacePool.Open()
        
        foreach ($file in $files) {
            $runspace = [powershell]::Create()
            $runspace.RunspacePool = $runspacePool
            $runspace.AddScript({
                param($filePath)
                "Content for $(Split-Path $filePath -Leaf)" | Out-File $filePath -Encoding UTF8
            }).AddArgument($file)
            
            $runspaces += [PSCustomObject]@{
                Runspace = $runspace
                Handle = $runspace.BeginInvoke()
            }
        }
        
        # Wait for completion
        $runspaces | ForEach-Object {
            $_.Runspace.EndInvoke($_.Handle)
            $_.Runspace.Dispose()
        }
        
        $runspacePool.Close()
        $runspacePool.Dispose()
        
        return ($files | Where-Object { Test-Path $_ }).Count
    } @{ Type = "Performance"; Feature = "ParallelProcessing" }
    
    # Test Windows memory-mapped files
    Measure-WindowsOperation "Memory-Mapped File Access" {
        $testFile = "$OutputPath/mmap-test.dat"
        $data = [byte[]](0..255)
        [System.IO.File]::WriteAllBytes($testFile, $data)
        
        # Use memory-mapped file for reading
        $fileStream = [System.IO.File]::OpenRead($testFile)
        $mmf = [System.IO.MemoryMappedFiles.MemoryMappedFile]::CreateFromFile($fileStream, $null, 0, [System.IO.MemoryMappedFiles.MemoryMappedFileAccess]::Read, $null, [System.IO.HandleInheritability]::None, $false)
        $accessor = $mmf.CreateViewAccessor(0, 0, [System.IO.MemoryMappedFiles.MemoryMappedFileAccess]::Read)
        
        $readData = New-Object byte[] 256
        $accessor.ReadArray(0, $readData, 0, 256)
        
        $accessor.Dispose()
        $mmf.Dispose()
        $fileStream.Close()
        
        return $readData.Length
    } @{ Type = "Performance"; Feature = "MemoryMappedFiles" }
    
    # Test Windows native API calls for file operations
    Measure-WindowsOperation "Native Windows API Usage" {
        Add-Type -TypeDefinition @"
            using System;
            using System.Runtime.InteropServices;
            public class WinAPI {
                [DllImport("kernel32.dll", SetLastError = true)]
                public static extern bool GetDiskFreeSpaceEx(string lpDirectoryName, out ulong lpFreeBytesAvailable, out ulong lpTotalNumberOfBytes, out ulong lpTotalNumberOfFreeBytes);
            }
"@
        
        $freeBytesAvailable = [ulong]0
        $totalNumberOfBytes = [ulong]0
        $totalNumberOfFreeBytes = [ulong]0
        
        $result = [WinAPI]::GetDiskFreeSpaceEx("C:\", [ref]$freeBytesAvailable, [ref]$totalNumberOfBytes, [ref]$totalNumberOfFreeBytes)
        
        return @{
            Success = $result
            FreeSpace = $freeBytesAvailable
            TotalSpace = $totalNumberOfBytes
        }
    } @{ Type = "Performance"; Feature = "NativeAPI" }
}

function Test-WindowsAdvancedScenarios {
    Write-TestHeader "Windows Advanced Scenarios"
    
    # Test Windows Service integration scenario
    Measure-WindowsOperation "Windows Service Simulation" {
        # Simulate operations that would run from a Windows service
        # Check if we can query services (requires appropriate permissions)
        $services = Get-Service | Where-Object { $_.Status -eq "Running" } | Select-Object -First 5
        
        return $services.Count -gt 0
    } @{ Type = "Advanced"; Feature = "ServiceIntegration" }
    
    # Test Windows Task Scheduler integration
    Measure-WindowsOperation "Task Scheduler Simulation" {
        # Simulate scheduled task operations
        # Create a simple scheduled task definition (without actually scheduling)
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-Command 'Write-Host Test'"
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(60)
        
        return ($null -ne $action -and $null -ne $trigger)
    } @{ Type = "Advanced"; Feature = "TaskScheduler" }
    
    # Test Windows Registry operations
    Measure-WindowsOperation "Registry Operations" {
        $testKey = "HKCU:\Software\GitZoom-Test"
        
        try {
            # Create test registry key
            New-Item -Path $testKey -Force | Out-Null
            Set-ItemProperty -Path $testKey -Name "TestValue" -Value "GitZoom Windows Test"
            
            # Read back the value
            $value = Get-ItemProperty -Path $testKey -Name "TestValue"
            
            # Clean up
            Remove-Item -Path $testKey -Force
            
            return $value.TestValue -eq "GitZoom Windows Test"
        }
        catch {
            return $false
        }
    } @{ Type = "Advanced"; Feature = "Registry" }
}

function Test-WindowsErrorHandling {
    Write-TestHeader "Windows Error Handling Tests"
    
    # Test access denied scenarios
    Measure-WindowsOperation "Access Denied Handling" {
        try {
            # Try to access a protected system file
            $systemFile = "$env:WINDIR\System32\config\SAM"
            Get-Content $systemFile -ErrorAction Stop
            return $false # Should not reach here
        }
        catch {
            return $_.Exception.Message -like "*access*denied*"
        }
    } @{ Type = "ErrorHandling"; Feature = "AccessDenied" } -ExpectFailure
    
    # Test path too long scenarios
    Measure-WindowsOperation "Path Too Long Handling" {
        try {
            $longPath = "C:\" + ("very-long-directory-name" * 20) + "\file.txt"
            Test-Path $longPath -IsValid
            return $true
        }
        catch {
            return $_.Exception.Message -like "*path*long*"
        }
    } @{ Type = "ErrorHandling"; Feature = "PathTooLong" }
    
    # Test network path unavailable
    Measure-WindowsOperation "Network Path Error Handling" {
        try {
            $networkPath = "\\nonexistent-server\share\file.txt"
            Test-Path $networkPath -ErrorAction Stop
            return $false
        }
        catch {
            return $_.Exception.Message -like "*network*" -or $_.Exception.Message -like "*find*"
        }
    } @{ Type = "ErrorHandling"; Feature = "NetworkPath" } -ExpectFailure
}

function New-DetailedReport {
    Write-TestHeader "Generating Detailed Report"
    
    $global:TestMetrics.EndTime = Get-Date
    $global:TestMetrics.TotalTestTime = ($global:TestMetrics.EndTime - $global:TestMetrics.StartTime).TotalSeconds
    
    $reportFile = "$OutputPath/windows-advanced-test-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    
    $report = @{
        TestRun = @{
            Timestamp = $global:TestMetrics.StartTime
            Duration = $global:TestMetrics.TotalTestTime
            TotalTests = $global:TestMetrics.TotalTests
            PassedTests = $global:TestMetrics.PassedTests
            FailedTests = $global:TestMetrics.FailedTests
            SuccessRate = [math]::Round(($global:TestMetrics.PassedTests / $global:TestMetrics.TotalTests) * 100, 2)
        }
        SystemInfo = @{
            OS = (Get-CimInstance Win32_OperatingSystem).Caption
            Version = (Get-CimInstance Win32_OperatingSystem).Version
            Architecture = $env:PROCESSOR_ARCHITECTURE
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            DotNetVersion = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
        }
        Results = $global:TestResults
    }
    
    $report | ConvertTo-Json -Depth 10 | Out-File $reportFile -Encoding UTF8
    
    Write-Host "📊 Detailed report saved to: $reportFile" -ForegroundColor Green
    
    # Display summary
    Write-Host ""
    Write-Host "📈 Test Summary" -ForegroundColor Yellow
    Write-Host "Total Tests: $($global:TestMetrics.TotalTests)" -ForegroundColor White
    Write-Host "Passed: $($global:TestMetrics.PassedTests)" -ForegroundColor Green
    Write-Host "Failed: $($global:TestMetrics.FailedTests)" -ForegroundColor Red
    Write-Host "Success Rate: $($report.TestRun.SuccessRate)%" -ForegroundColor Cyan
    Write-Host "Total Duration: $([math]::Round($global:TestMetrics.TotalTestTime, 2)) seconds" -ForegroundColor White
}

# Main execution
Write-Host "Starting Windows Advanced Testing Suite..." -ForegroundColor Yellow
Write-Host "Test Suite: $TestSuite | Iterations: $Iterations" -ForegroundColor Gray
Write-Host ""

# Run test suites based on parameter
switch ($TestSuite.ToLower()) {
    "filesystem" { Test-WindowsFileSystemOperations }
    "git" { Test-WindowsGitIntegration }
    "performance" { Test-WindowsPerformanceOptimizations }
    "advanced" { Test-WindowsAdvancedScenarios }
    "errors" { Test-WindowsErrorHandling }
    "all" {
        Test-WindowsFileSystemOperations
        Test-WindowsGitIntegration
        Test-WindowsPerformanceOptimizations
        Test-WindowsAdvancedScenarios
        Test-WindowsErrorHandling
    }
    default {
        Write-Host "Unknown test suite: $TestSuite" -ForegroundColor Red
        Write-Host "Available suites: filesystem, git, performance, advanced, errors, all" -ForegroundColor Yellow
        exit 1
    }
}

if ($GenerateDetailedReport) {
    New-DetailedReport
}

Write-Host ""
Write-Host "🎉 Windows Advanced Testing Complete!" -ForegroundColor Magenta