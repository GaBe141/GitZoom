<#
.SYNOPSIS
    Basic validation tests for GitZoom library using Pester 3.x compatible syntax
    
.DESCRIPTION
    Simple tests to validate core GitZoom functionality without complex setups.
    These tests use Pester 3.x compatible syntax and focus on basic functionality.
#>

Describe "GitZoom Basic Validation" {
    BeforeAll {
        # Import GitZoom module using manifest
        $ModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "lib\GitZoom.psd1"
        Import-Module $ModulePath -Force
        
        # Create test directory
        $script:TestDir = Join-Path $env:TEMP "GitZoomBasicTests"
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
    
    Context "Module Loading" {
        It "Should load GitZoom module without errors" {
            $module = Get-Module GitZoom
            $module | Should Not Be $null
        }
        
        It "Should export expected functions" {
            $functions = Get-Command -Module GitZoom
            $functions.Count | Should BeGreaterThan 0
            
            # Check for key functions
            $functionNames = $functions.Name
            $functionNames -contains "Initialize-GitZoom" | Should Be $true
            $functionNames -contains "Add-GitZoomFile" | Should Be $true
            $functionNames -contains "Get-GitZoomStatus" | Should Be $true
        }
    }
    
    Context "Basic Functionality" {
        It "Should initialize GitZoom without errors" {
            # Initialize a Git repository first
            Push-Location $script:TestDir
            try {
                git init --quiet
                git config user.email "test@example.com"
                git config user.name "Test User"
                
                # Test basic function execution
                { Initialize-GitZoom -Path $script:TestDir } | Should Not Throw
            }
            finally {
                Pop-Location
            }
        }
        
        It "Should provide status information" {
            Push-Location $script:TestDir
            try {
                # Test that the function runs without error
                { Get-GitZoomStatus } | Should Not Throw
            }
            finally {
                Pop-Location
            }
        }
    }
    
    Context "Utility Functions" {
        It "Should validate Git repository detection" {
            # Create a temporary Git repo
            Push-Location $script:TestDir
            try {
                git init --quiet
                $isRepo = Test-GitRepository
                $isRepo | Should Be $true
            }
            finally {
                Pop-Location
            }
        }
        
        It "Should format file sizes correctly" {
            $formatted = Format-FileSize -Bytes 1024
            $formatted | Should Not Be $null
            $formatted | Should Match "KB|MB|GB|B"
        }
        
        It "Should format durations correctly" {
            $duration = [TimeSpan]::FromSeconds(65.5)
            $formatted = Format-Duration -TimeSpan $duration
            $formatted | Should Not Be $null
            $formatted | Should Match "s|ms|m"
        }
    }
}