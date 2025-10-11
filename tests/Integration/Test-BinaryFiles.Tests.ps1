<#
.SYNOPSIS
    Integration tests for GitZoom with binary files

.DESCRIPTION
    Tests GitZoom handling of various binary file types including images,
    compiled binaries, archives, and office documents.
#>

BeforeAll {
    Import-Module $PSScriptRoot/../../lib/GitZoom.psd1 -Force
    
    $script:TestRepoPath = Join-Path $TestDrive "binary-files-test"
}

Describe "Binary Files Integration Tests" -Tag "Integration", "BinaryFiles" {
    
    BeforeEach {
        New-Item -ItemType Directory -Path $script:TestRepoPath -Force | Out-Null
        Push-Location $script:TestRepoPath
        git init | Out-Null
        git config user.email "test@gitzoom.test"
        git config user.name "GitZoom Test"
    }
    
    AfterEach {
        Pop-Location
        if (Test-Path $script:TestRepoPath) {
            Remove-Item -Recurse -Force $script:TestRepoPath -ErrorAction SilentlyContinue
        }
    }
    
    Context "Image files" {
        
        It "Should handle PNG files" {
            # Create a minimal PNG file (1x1 transparent pixel)
            $pngBytes = [byte[]](137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82,0,0,0,1,0,0,0,1,8,6,0,0,0,31,21,196,137,0,0,0,10,73,68,65,84,120,156,99,0,1,0,0,5,0,1,13,10,45,180,0,0,0,0,73,69,78,68,174,66,96,130)
            [System.IO.File]::WriteAllBytes((Join-Path $script:TestRepoPath "test.png"), $pngBytes)
            
            $stageResult = Invoke-GitZoomStage -Path "test.png"
            $stageResult.Success | Should -Be $true
            
            $commitResult = Invoke-GitZoomCommit -Message "Add PNG image"
            $commitResult.Success | Should -Be $true
        }
        
        It "Should handle multiple image formats" {
            # Create test binary files
            $formats = @("png", "jpg", "gif", "bmp")
            
            foreach ($format in $formats) {
                $testBytes = [byte[]](1..100)
                [System.IO.File]::WriteAllBytes((Join-Path $script:TestRepoPath "test.$format"), $testBytes)
            }
            
            $stageResult = Invoke-GitZoomStage -All
            $stageResult.Success | Should -Be $true
            $stageResult.FilesStaged | Should -Be 4
        }
    }
    
    Context "Compiled binaries" {
        
        It "Should handle EXE files" {
            # Create a dummy EXE (MZ header)
            $exeBytes = [byte[]](0x4D, 0x5A) + ([byte[]](1..100))
            [System.IO.File]::WriteAllBytes((Join-Path $script:TestRepoPath "app.exe"), $exeBytes)
            
            $stageResult = Invoke-GitZoomStage -Path "app.exe"
            $stageResult.Success | Should -Be $true
            
            $commitResult = Invoke-GitZoomCommit -Message "Add executable"
            $commitResult.Success | Should -Be $true
        }
        
        It "Should handle DLL files" {
            # Create a dummy DLL
            $dllBytes = [byte[]](0x4D, 0x5A) + ([byte[]](1..100))
            [System.IO.File]::WriteAllBytes((Join-Path $script:TestRepoPath "library.dll"), $dllBytes)
            
            $stageResult = Invoke-GitZoomStage -Path "library.dll"
            $stageResult.Success | Should -Be $true
        }
    }
    
    Context "Archive files" {
        
        It "Should handle ZIP files" {
            # Create a minimal ZIP file
            $zipBytes = [byte[]](0x50, 0x4B, 0x03, 0x04) + ([byte[]](1..100))
            [System.IO.File]::WriteAllBytes((Join-Path $script:TestRepoPath "archive.zip"), $zipBytes)
            
            $stageResult = Invoke-GitZoomStage -Path "archive.zip"
            $stageResult.Success | Should -Be $true
            
            $commitResult = Invoke-GitZoomCommit -Message "Add archive"
            $commitResult.Success | Should -Be $true
        }
    }
    
    Context "Mixed text and binary files" {
        
        It "Should handle repository with mixed file types" {
            # Create text files
            "Text content 1" | Set-Content "readme.txt"
            "Text content 2" | Set-Content "notes.md"
            
            # Create binary files
            $binaryBytes = [byte[]](1..100)
            [System.IO.File]::WriteAllBytes((Join-Path $script:TestRepoPath "data.bin"), $binaryBytes)
            [System.IO.File]::WriteAllBytes((Join-Path $script:TestRepoPath "image.png"), $binaryBytes)
            
            $stageResult = Invoke-GitZoomStage -All
            $stageResult.Success | Should -Be $true
            $stageResult.FilesStaged | Should -Be 4
            
            $commitResult = Invoke-GitZoomCommit -Message "Mixed files"
            $commitResult.Success | Should -Be $true
        }
    }
    
    Context "Binary file modifications" {
        
        It "Should detect binary file changes" {
            # Create and commit initial binary file
            $bytes1 = [byte[]](1..50)
            [System.IO.File]::WriteAllBytes((Join-Path $script:TestRepoPath "data.bin"), $bytes1)
            
            Invoke-GitZoomStage -Path "data.bin" | Out-Null
            Invoke-GitZoomCommit -Message "Initial binary" | Out-Null
            
            # Modify binary file
            $bytes2 = [byte[]](51..100)
            [System.IO.File]::WriteAllBytes((Join-Path $script:TestRepoPath "data.bin"), $bytes2)
            
            # Check if modification is detected
            $status = git status --porcelain
            $status | Should -Match "data.bin"
            
            # Stage and commit changes
            $stageResult = Invoke-GitZoomStage -Path "data.bin"
            $stageResult.Success | Should -Be $true
            
            $commitResult = Invoke-GitZoomCommit -Message "Update binary"
            $commitResult.Success | Should -Be $true
        }
    }
    
    Context "Performance with binary files" {
        
        It "Should handle multiple large binary files efficiently" {
            # Create 10 binary files of 5MB each
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            1..10 | ForEach-Object {
                $largeBytes = [byte[]](1..(5 * 1024 * 1024))
                [System.IO.File]::WriteAllBytes((Join-Path $script:TestRepoPath "large$_.bin"), $largeBytes)
            }
            
            $stageResult = Invoke-GitZoomStage -All
            $stageResult.Success | Should -Be $true
            $stageResult.FilesStaged | Should -Be 10
            
            $commitResult = Invoke-GitZoomCommit -Message "Large binary files"
            $commitResult.Success | Should -Be $true
            
            $stopwatch.Stop()
            
            # Should complete in reasonable time (under 30 seconds)
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 30000
        }
    }
}
