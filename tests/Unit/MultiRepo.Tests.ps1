<#
.SYNOPSIS
    Unit tests for GitZoom multi-repository functions

.DESCRIPTION
    Tests for Invoke-GitFetchAll and Get-GitStatusAll functions
#>

BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot "../../lib/GitZoom.psd1"
    Import-Module $modulePath -Force
}

Describe "Invoke-GitFetchAll" -Tag "MultiRepo", "Fetch" {
    
    BeforeAll {
        # Create test directory structure
        $script:TestRoot = Join-Path $TestDrive "MultiRepoTest"
        New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
        
        # Create mock repositories
        $script:Repo1 = Join-Path $script:TestRoot "Repo1"
        $script:Repo2 = Join-Path $script:TestRoot "Repo2"
        $script:Repo3 = Join-Path $script:TestRoot "SubDir\Repo3"
        
        foreach ($repo in @($script:Repo1, $script:Repo2, $script:Repo3)) {
            New-Item -ItemType Directory -Path $repo -Force | Out-Null
            Push-Location $repo
            git init | Out-Null
            git config user.email "test@gitzoom.test"
            git config user.name "GitZoom Test"
            "Test" | Set-Content "test.txt"
            git add . | Out-Null
            git commit -m "Initial commit" | Out-Null
            Pop-Location
        }
    }
    
    AfterAll {
        if (Test-Path $script:TestRoot) {
            Remove-Item -Recurse -Force $script:TestRoot -ErrorAction SilentlyContinue
        }
    }
    
    Context "Repository Discovery" {
        
        It "Should find repositories in a directory" {
            $result = Invoke-GitFetchAll -Path $script:TestRoot -ErrorAction SilentlyContinue
            
            # Should find at least the two top-level repos
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -BeGreaterOrEqual 2
        }
        
        It "Should find repositories recursively when -Recurse is specified" {
            $result = Invoke-GitFetchAll -Path $script:TestRoot -Recurse -ErrorAction SilentlyContinue
            
            # Should find all three repos
            $result.Count | Should -Be 3
        }
        
        It "Should accept multiple paths" {
            $result = Invoke-GitFetchAll -Path @($script:Repo1, $script:Repo2) -ErrorAction SilentlyContinue
            
            $result.Count | Should -Be 2
        }
        
        It "Should warn when path does not exist" {
            $nonExistentPath = Join-Path $script:TestRoot "DoesNotExist"
            
            { Invoke-GitFetchAll -Path $nonExistentPath -ErrorAction Stop } | Should -Throw
        }
    }
    
    Context "Parallel Execution" {
        
        It "Should respect MaxParallel parameter" {
            $result = Invoke-GitFetchAll -Path $script:TestRoot -Recurse -MaxParallel 2 -ErrorAction SilentlyContinue
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should return results for all repositories" {
            $result = Invoke-GitFetchAll -Path $script:TestRoot -Recurse -ErrorAction SilentlyContinue
            
            $result | Should -HaveCount 3
            $result | ForEach-Object {
                $_ | Should -HaveProperty 'Repository'
                $_ | Should -HaveProperty 'Success'
                $_ | Should -HaveProperty 'Duration'
            }
        }
    }
    
    Context "Result Format" {
        
        It "Should return objects with required properties" {
            $result = Invoke-GitFetchAll -Path $script:Repo1 -ErrorAction SilentlyContinue
            
            $result | Should -Not -BeNullOrEmpty
            $result[0].PSObject.Properties.Name | Should -Contain 'Repository'
            $result[0].PSObject.Properties.Name | Should -Contain 'Path'
            $result[0].PSObject.Properties.Name | Should -Contain 'Success'
            $result[0].PSObject.Properties.Name | Should -Contain 'Message'
            $result[0].PSObject.Properties.Name | Should -Contain 'Duration'
        }
    }
}

Describe "Get-GitStatusAll" -Tag "MultiRepo", "Status" {
    
    BeforeAll {
        # Create test directory structure
        $script:TestRoot = Join-Path $TestDrive "MultiRepoStatusTest"
        New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
        
        # Create clean repository
        $script:CleanRepo = Join-Path $script:TestRoot "CleanRepo"
        New-Item -ItemType Directory -Path $script:CleanRepo -Force | Out-Null
        Push-Location $script:CleanRepo
        git init | Out-Null
        git config user.email "test@gitzoom.test"
        git config user.name "GitZoom Test"
        "Test" | Set-Content "test.txt"
        git add . | Out-Null
        git commit -m "Initial commit" | Out-Null
        Pop-Location
        
        # Create repository with uncommitted changes
        $script:DirtyRepo = Join-Path $script:TestRoot "DirtyRepo"
        New-Item -ItemType Directory -Path $script:DirtyRepo -Force | Out-Null
        Push-Location $script:DirtyRepo
        git init | Out-Null
        git config user.email "test@gitzoom.test"
        git config user.name "GitZoom Test"
        "Test" | Set-Content "test.txt"
        git add . | Out-Null
        git commit -m "Initial commit" | Out-Null
        "Modified" | Set-Content "test.txt"
        "New file" | Set-Content "new.txt"
        Pop-Location
    }
    
    AfterAll {
        if (Test-Path $script:TestRoot) {
            Remove-Item -Recurse -Force $script:TestRoot -ErrorAction SilentlyContinue
        }
    }
    
    Context "Repository Discovery" {
        
        It "Should find repositories in a directory" {
            $result = Get-GitStatusAll -Path $script:TestRoot -IncludeClean
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -BeGreaterOrEqual 2
        }
        
        It "Should find repositories recursively when -Recurse is specified" {
            # Create nested repo
            $nestedRepo = Join-Path $script:TestRoot "SubDir\NestedRepo"
            New-Item -ItemType Directory -Path $nestedRepo -Force | Out-Null
            Push-Location $nestedRepo
            git init | Out-Null
            git config user.email "test@gitzoom.test"
            git config user.name "GitZoom Test"
            "Test" | Set-Content "test.txt"
            git add . | Out-Null
            git commit -m "Initial commit" | Out-Null
            Pop-Location
            
            $result = Get-GitStatusAll -Path $script:TestRoot -Recurse -IncludeClean
            
            $result.Count | Should -BeGreaterOrEqual 3
        }
    }
    
    Context "Status Detection" {
        
        It "Should detect uncommitted changes" {
            $result = Get-GitStatusAll -Path $script:DirtyRepo
            
            $result | Should -Not -BeNullOrEmpty
            $result[0].Uncommitted | Should -BeGreaterThan 0
            $result[0].Status | Should -Not -Be "Clean"
        }
        
        It "Should exclude clean repositories by default" {
            $result = Get-GitStatusAll -Path $script:TestRoot
            
            # Should only find dirty repo, not clean repo
            $cleanRepos = $result | Where-Object { $_.Status -eq "Clean" }
            $cleanRepos | Should -BeNullOrEmpty
        }
        
        It "Should include clean repositories when -IncludeClean is specified" {
            $result = Get-GitStatusAll -Path $script:TestRoot -IncludeClean
            
            $cleanRepos = $result | Where-Object { $_.Status -eq "Clean" }
            $cleanRepos | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Result Format" {
        
        It "Should return objects with required properties" {
            $result = Get-GitStatusAll -Path $script:DirtyRepo
            
            $result | Should -Not -BeNullOrEmpty
            $result[0].PSObject.Properties.Name | Should -Contain 'Repository'
            $result[0].PSObject.Properties.Name | Should -Contain 'Path'
            $result[0].PSObject.Properties.Name | Should -Contain 'Branch'
            $result[0].PSObject.Properties.Name | Should -Contain 'Status'
            $result[0].PSObject.Properties.Name | Should -Contain 'Uncommitted'
        }
        
        It "Should support Table format" {
            { Get-GitStatusAll -Path $script:DirtyRepo -Format Table } | Should -Not -Throw
        }
        
        It "Should support List format" {
            { Get-GitStatusAll -Path $script:DirtyRepo -Format List } | Should -Not -Throw
        }
    }
    
    Context "Branch Information" {
        
        It "Should detect current branch" {
            $result = Get-GitStatusAll -Path $script:CleanRepo -IncludeClean
            
            $result | Should -Not -BeNullOrEmpty
            $result[0].Branch | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Multi-Repo Integration" -Tag "MultiRepo", "Integration" {
    
    Context "Pipeline Support" {
        
        It "Invoke-GitFetchAll should accept paths from pipeline" {
            $testPath = Join-Path $TestDrive "PipelineTest"
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            
            # Create a test repo
            Push-Location $testPath
            git init | Out-Null
            git config user.email "test@gitzoom.test"
            git config user.name "GitZoom Test"
            "Test" | Set-Content "test.txt"
            git add . | Out-Null
            git commit -m "Initial commit" | Out-Null
            Pop-Location
            
            { $testPath | Invoke-GitFetchAll -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Get-GitStatusAll should accept paths from pipeline" {
            $testPath = Join-Path $TestDrive "PipelineTest2"
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            
            # Create a test repo
            Push-Location $testPath
            git init | Out-Null
            git config user.email "test@gitzoom.test"
            git config user.name "GitZoom Test"
            "Test" | Set-Content "test.txt"
            git add . | Out-Null
            git commit -m "Initial commit" | Out-Null
            Pop-Location
            
            { $testPath | Get-GitStatusAll -IncludeClean } | Should -Not -Throw
        }
    }
}
