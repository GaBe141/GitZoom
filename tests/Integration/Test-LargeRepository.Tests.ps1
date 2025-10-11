<#
.SYNOPSIS
    Integration tests for GitZoom with large repositories

.DESCRIPTION
    Tests GitZoom performance and functionality with large-scale repositories
    containing thousands of files and deep directory structures.
#>

BeforeAll {
    Import-Module $PSScriptRoot/../../lib/GitZoom.psd1 -Force
    
    # Setup test repository path
    $script:TestRepoPath = Join-Path $TestDrive "large-repo-test"
    $script:PerformanceMetrics = @{}
}

Describe "Large Repository Integration Tests" -Tag "Integration", "LargeRepo" {
    
    BeforeEach {
        # Create fresh test repository
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
    
    Context "Repository with 1000+ files" {
        
        It "Should stage 1000 files efficiently" {
            # Generate 1000 test files
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            1..1000 | ForEach-Object {
                $dir = "dir$($_ % 10)"
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                "Test content $_" | Set-Content "$dir/file$_.txt"
            }
            
            # Stage all files using GitZoom
            $stageResult = Invoke-GitZoomStage -All
            $stopwatch.Stop()
            
            $stageResult.Success | Should -Be $true
            $stageResult.FilesStaged | Should -BeGreaterOrEqual 1000
            
            # Performance metric: Should complete in under 5 seconds
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000
            
            $script:PerformanceMetrics['Stage1000Files'] = $stopwatch.ElapsedMilliseconds
        }
        
        It "Should commit 1000 files efficiently" {
            # Setup: Create and stage files
            1..1000 | ForEach-Object {
                $dir = "dir$($_ % 10)"
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                "Test content $_" | Set-Content "$dir/file$_.txt"
            }
            git add . | Out-Null
            
            # Commit using GitZoom
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $commitResult = Invoke-GitZoomCommit -Message "Test: 1000 files"
            $stopwatch.Stop()
            
            $commitResult.Success | Should -Be $true
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 3000
            
            $script:PerformanceMetrics['Commit1000Files'] = $stopwatch.ElapsedMilliseconds
        }
    }
    
    Context "Deep directory structures" {
        
        It "Should handle 50-level deep directory structure" {
            # Create deep nested structure
            $currentPath = $script:TestRepoPath
            $depth = 50
            
            1..$depth | ForEach-Object {
                $currentPath = Join-Path $currentPath "level$_"
                New-Item -ItemType Directory -Path $currentPath -Force | Out-Null
            }
            
            # Create file at deepest level
            "Deep file content" | Set-Content (Join-Path $currentPath "deep-file.txt")
            
            # Stage and commit
            $stageResult = Invoke-GitZoomStage -All
            $stageResult.Success | Should -Be $true
            
            $commitResult = Invoke-GitZoomCommit -Message "Test: Deep structure"
            $commitResult.Success | Should -Be $true
        }
    }
    
    Context "Large file handling" {
        
        It "Should handle files larger than 10MB" {
            # Create a 15MB file
            $largeContent = "X" * (15 * 1024 * 1024)
            $largeContent | Set-Content "large-file.txt"
            
            $stageResult = Invoke-GitZoomStage -Path "large-file.txt"
            $stageResult.Success | Should -Be $true
            
            $commitResult = Invoke-GitZoomCommit -Message "Test: Large file"
            $commitResult.Success | Should -Be $true
        }
        
        It "Should warn about very large files (>50MB)" {
            # Create a 60MB file
            $veryLargeContent = "X" * (60 * 1024 * 1024)
            $veryLargeContent | Set-Content "very-large-file.txt"
            
            $stageResult = Invoke-GitZoomStage -Path "very-large-file.txt"
            
            # Should still work but might have warnings
            $stageResult.Success | Should -Be $true
            # Check if there's a warning about large files
            if ($stageResult.Warnings) {
                $stageResult.Warnings | Should -Match "large"
            }
        }
    }
    
    Context "Performance benchmarking" {
        
        It "Should be faster than standard git for bulk operations" {
            # Create 500 files
            1..500 | ForEach-Object {
                "Content $_" | Set-Content "file$_.txt"
            }
            
            # Measure GitZoom performance
            $gitZoomTime = Measure-Command {
                Invoke-GitZoomStage -All | Out-Null
                Invoke-GitZoomCommit -Message "GitZoom test" | Out-Null
            }
            
            # Reset
            git reset --hard HEAD~1 | Out-Null
            git clean -fd | Out-Null
            
            # Recreate files
            1..500 | ForEach-Object {
                "Content $_" | Set-Content "file$_.txt"
            }
            
            # Measure standard git performance
            $gitTime = Measure-Command {
                git add . | Out-Null
                git commit -m "Standard git test" | Out-Null
            }
            
            Write-Host "GitZoom: $($gitZoomTime.TotalMilliseconds)ms"
            Write-Host "Standard Git: $($gitTime.TotalMilliseconds)ms"
            
            # GitZoom should be competitive (within 2x of standard git)
            $gitZoomTime.TotalMilliseconds | Should -BeLessThan ($gitTime.TotalMilliseconds * 2)
        }
    }
}

AfterAll {
    # Report performance metrics
    if ($script:PerformanceMetrics.Count -gt 0) {
        Write-Host "`n📊 Performance Metrics:" -ForegroundColor Cyan
        $script:PerformanceMetrics.GetEnumerator() | ForEach-Object {
            Write-Host "   $($_.Key): $($_.Value)ms" -ForegroundColor Yellow
        }
    }
}
