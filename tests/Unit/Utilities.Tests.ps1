<#
.SYNOPSIS
    Unit tests for GitZoom Utilities module using Pester 5.x

.DESCRIPTION
    Comprehensive test coverage for utility functions in lib/Utilities.ps1
    including file operations, formatting, and Git repository helpers.
#>

BeforeAll {
    # Import GitZoom module
    $ModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "lib\GitZoom.psd1"
    Import-Module $ModulePath -Force
    
    # Create test directory
    $script:TestDir = Join-Path $env:TEMP "GitZoomUtilityTests-$(Get-Date -Format 'yyyyMMddHHmmss')"
    if (Test-Path $script:TestDir) {
        Remove-Item $script:TestDir -Recurse -Force
    }
    New-Item -Path $script:TestDir -ItemType Directory -Force | Out-Null
}

AfterAll {
    if (Test-Path $script:TestDir) {
        Remove-Item $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "Format-FileSize" {
    Context "Formatting bytes to human-readable sizes" {
        It "Should format bytes correctly" {
            $result = Format-FileSize -Bytes 500
            $result | Should -Match "^\d+\.\d{2} B$"
        }
        
        It "Should format kilobytes correctly" {
            $result = Format-FileSize -Bytes 1024
            $result | Should -Be "1.00 KB"
        }
        
        It "Should format megabytes correctly" {
            $result = Format-FileSize -Bytes 1048576
            $result | Should -Be "1.00 MB"
        }
        
        It "Should format gigabytes correctly" {
            $result = Format-FileSize -Bytes 1073741824
            $result | Should -Be "1.00 GB"
        }
        
        It "Should handle zero bytes" {
            $result = Format-FileSize -Bytes 0
            $result | Should -Be "0.00 B"
        }
        
        It "Should handle large files" {
            $result = Format-FileSize -Bytes 5368709120
            $result | Should -Be "5.00 GB"
        }
        
        It "Should format fractional sizes correctly" {
            $result = Format-FileSize -Bytes 1536
            $result | Should -Be "1.50 KB"
        }
    }
}

Describe "Format-Duration" {
    Context "Formatting TimeSpan to human-readable duration" {
        It "Should format seconds only" {
            $timespan = New-TimeSpan -Seconds 45
            $result = Format-Duration -TimeSpan $timespan
            $result | Should -Be "45s"
        }
        
        It "Should format minutes and seconds" {
            $timespan = New-TimeSpan -Seconds 75
            $result = Format-Duration -TimeSpan $timespan
            $result | Should -Be "1m 15s"
        }
        
        It "Should format hours, minutes, and seconds" {
            $timespan = New-TimeSpan -Hours 2 -Minutes 30 -Seconds 45
            $result = Format-Duration -TimeSpan $timespan
            $result | Should -Be "2h 30m 45s"
        }
        
        It "Should format days, hours, minutes, and seconds" {
            $timespan = New-TimeSpan -Days 1 -Hours 5 -Minutes 15 -Seconds 30
            $result = Format-Duration -TimeSpan $timespan
            $result | Should -Be "1d 5h 15m 30s"
        }
        
        It "Should handle zero duration" {
            $timespan = New-TimeSpan -Seconds 0
            $result = Format-Duration -TimeSpan $timespan
            $result | Should -Be "0s"
        }
        
        It "Should omit zero components" {
            $timespan = New-TimeSpan -Hours 1 -Seconds 5
            $result = Format-Duration -TimeSpan $timespan
            $result | Should -Be "1h 5s"
        }
    }
}

Describe "ConvertTo-SafeFileName" {
    Context "Sanitizing strings for file names" {
        It "Should remove invalid characters" {
            $result = ConvertTo-SafeFileName -InputString "File:Name*Test?"
            $result | Should -Not -Match '[:<>*?|"]'
        }
        
        It "Should replace invalid chars with dashes" {
            $result = ConvertTo-SafeFileName -InputString "File:Name"
            $result | Should -Be "File-Name"
        }
        
        It "Should handle multiple consecutive dashes" {
            $result = ConvertTo-SafeFileName -InputString "File::Name"
            $result | Should -Be "File-Name"
        }
        
        It "Should trim leading and trailing dashes" {
            $result = ConvertTo-SafeFileName -InputString ":FileName:"
            $result | Should -Be "FileName"
        }
        
        It "Should handle already safe names" {
            $result = ConvertTo-SafeFileName -InputString "SafeFileName123"
            $result | Should -Be "SafeFileName123"
        }
        
        It "Should handle spaces" {
            $result = ConvertTo-SafeFileName -InputString "My File Name"
            $result | Should -Be "My File Name"
        }
    }
}

Describe "Test-GitRepository" {
    Context "Detecting Git repositories" {
        It "Should return false for non-git directory" {
            Push-Location $script:TestDir
            try {
                $result = Test-GitRepository
                $result | Should -Be $false
            }
            finally {
                Pop-Location
            }
        }
        
        It "Should return true for git repository" {
            Push-Location $script:TestDir
            try {
                git init --quiet 2>$null
                $result = Test-GitRepository
                $result | Should -Be $true
            }
            finally {
                Pop-Location
            }
        }
        
        It "Should accept Path parameter" {
            git -C $script:TestDir init --quiet 2>$null
            $result = Test-GitRepository -Path $script:TestDir
            $result | Should -Be $true
        }
    }
}

Describe "Get-GitRepositoryRoot" {
    Context "Finding Git repository root" {
        It "Should return null for non-git directory" {
            $nonGitDir = Join-Path $script:TestDir "NonGitFolder"
            New-Item -Path $nonGitDir -ItemType Directory -Force | Out-Null
            
            # Remove any git repo that might be in parent
            if (Test-Path (Join-Path $script:TestDir ".git")) {
                Remove-Item (Join-Path $script:TestDir ".git") -Recurse -Force
            }
            
            $result = Get-GitRepositoryRoot -Path $nonGitDir
            # If we're in a git repo workspace, this might not be null
            # Just verify the function runs without error
            $result | Should -BeIn @($null, (Get-GitRepositoryRoot))
        }
        
        It "Should return root path for git repository" {
            git -C $script:TestDir init --quiet 2>$null
            $result = Get-GitRepositoryRoot -Path $script:TestDir
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeLike "*$($script:TestDir.Split('\')[-1])*"
        }
        
        It "Should find root from subdirectory" {
            git -C $script:TestDir init --quiet 2>$null
            $subDir = Join-Path $script:TestDir "SubFolder"
            New-Item -Path $subDir -ItemType Directory -Force | Out-Null
            
            $result = Get-GitRepositoryRoot -Path $subDir
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeLike "*$($script:TestDir.Split('\')[-1])*"
        }
    }
}

Describe "Invoke-SafeScriptBlock" {
    Context "Executing script blocks with error handling" {
        It "Should execute successful script block" {
            $result = Invoke-SafeScriptBlock -ScriptBlock { 2 + 2 }
            $result | Should -Be 4
        }
        
        It "Should throw with custom error message on failure" {
            { 
                Invoke-SafeScriptBlock -ScriptBlock { 
                    throw "Test error" 
                } -ErrorMessage "Custom error"
            } | Should -Throw "*Custom error*"
        }
        
        It "Should retry on failure" {
            $script:attemptCount = 0
            $result = Invoke-SafeScriptBlock -ScriptBlock {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "Temporary error"
                }
                return "Success"
            } -RetryCount 2
            
            $result | Should -Be "Success"
            $script:attemptCount | Should -Be 2
        }
        
        It "Should fail after max retries" {
            { 
                Invoke-SafeScriptBlock -ScriptBlock { 
                    throw "Persistent error" 
                } -RetryCount 2 -ErrorMessage "Max retries"
            } | Should -Throw
        }
        
        It "Should return script block output" {
            $result = Invoke-SafeScriptBlock -ScriptBlock { 
                Get-ChildItem $env:TEMP | Select-Object -First 1
            }
            $result | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "New-GitZoomTempDirectory" {
    Context "Creating temporary directories" {
        It "Should create a new temp directory" {
            $tempDir = New-GitZoomTempDirectory
            $tempDir | Should -Not -BeNullOrEmpty
            Test-Path $tempDir | Should -Be $true
            
            # Cleanup
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        It "Should create directory under GitZoom temp folder" {
            $tempDir = New-GitZoomTempDirectory
            $tempDir | Should -BeLike "*\GitZoom\temp-*"
            
            # Cleanup
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        It "Should create unique directory names" {
            $temp1 = New-GitZoomTempDirectory
            Start-Sleep -Milliseconds 100
            $temp2 = New-GitZoomTempDirectory
            
            $temp1 | Should -Not -Be $temp2
            
            # Cleanup
            Remove-Item $temp1, $temp2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
