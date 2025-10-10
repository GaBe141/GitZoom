<#
.SYNOPSIS
    Property-based tests for GitZoom using Pester.
.DESCRIPTION
    Tests function properties and invariants using randomly generated data,
    rather than fixed examples. This helps uncover edge cases.
#>

BeforeAll {
    # Pester's -TestCases feature provides a simple way to do property-based testing.
    # For more advanced scenarios, a dedicated library might be used.
    Import-Module (Join-Path $PSScriptRoot '..\..\lib\GitZoom.psm1') -Force
}

Describe "Property-Based Tests for Utilities" {

    Context "Format-CommitMessage" {
        # Property: The function should never return a message with leading/trailing whitespace.
        It "Should always trim whitespace from messages" {
            $testCases = 1..20 | ForEach-Object {
                $leadingSpaces = " " * (Get-Random -Minimum 1 -Maximum 10)
                $trailingSpaces = " " * (Get-Random -Minimum 1 -Maximum 10)
                $randomString = -join ((65..90) + (97..122) | Get-Random -Count 15 | ForEach-Object {[char]$_})
                @{ Input = "$leadingSpaces$randomString$trailingSpaces"; Expected = $randomString }
            }

            foreach ($case in $testCases) {
                Format-CommitMessage -Message $case.Input | Should -Be $case.Expected
            }
        }

        # Property: Any non-empty message should result in a non-empty formatted message.
        It "Should not produce an empty output from a non-empty input" {
             $testCases = 1..20 | ForEach-Object {
                @{ Input = -join ((32..126) | Get-Random -Count 25 | ForEach-Object {[char]$_}) }
            }

            foreach ($case in $testCases) {
                if ($case.Input.Trim()) {
                    Format-CommitMessage -Message $case.Input | Should -Not -BeNullOrEmpty
                }
            }
        }
    }

    Context "Build-CommitMessage (Internal Function)" {
        # Property: The function should correctly combine type, scope, and subject.
        It "Should correctly construct a conventional commit message" {
            $types = @('feat', 'fix', 'docs', 'style', 'refactor', 'test', 'chore')
            $scopes = @('staging', 'commit', 'core', 'utils', '', 'api')

            $testCases = 1..20 | ForEach-Object {
                $type = Get-Random -InputObject $types
                $scope = Get-Random -InputObject $scopes
                $subject = "random subject " + (Get-Random)
                $expected = if ($scope) { "$( $type )($($scope)): $($subject)" } else { "$( $type ): $($subject)" }
                @{ Type = $type; Scope = $scope; Subject = $subject; Expected = $expected }
            }

            foreach ($case in $testCases) {
                # Using Invoke-Command to test an internal (non-exported) function
                $scriptBlock = {
                    param($Type, $Scope, $Subject)
                    Build-CommitMessage -Type $Type -Scope $Scope -Subject $Subject
                }
                $moduleInfo = Get-Module GitZoom
                Invoke-Command -Module $moduleInfo -ScriptBlock $scriptBlock -ArgumentList $case.Type, $case.Scope, $case.Subject | Should -Be $case.Expected
            }
        }
    }
}
