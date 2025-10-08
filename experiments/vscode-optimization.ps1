# VS Code Integration Optimization Experiments
param(
    [string]$ConfigType = "all",
    [switch]$ApplyOptimizations,
    [switch]$ResetToDefaults
)

Write-Host "⚙️ VS Code Integration Optimization" -ForegroundColor Magenta
Write-Host "=" * 50 -ForegroundColor Gray

# ============================================================================
# EXPERIMENTAL VS CODE SETTINGS
# ============================================================================

$experimentalSettings = @{
    # Git Performance Optimizations
    "git.autofetch" = $true
    "git.autofetchPeriod" = 30
    "git.enableSmartCommit" = $true
    "git.autoStash" = $true
    "git.rebaseWhenSync" = $true
    "git.pullBeforePublish" = $true
    "git.fetchOnPull" = $true
    "git.pruneOnFetch" = $true
    
    # Editor Performance for Git Workflows
    "editor.quickSuggestions" = @{
        "comments" = $false
        "strings" = $true
        "other" = $true
    }
    "editor.suggestOnTriggerCharacters" = $true
    "editor.acceptSuggestionOnCommitCharacter" = $true
    "editor.wordBasedSuggestions" = $false
    
    # File Watching Optimizations
    "files.watcherExclude" = @{
        "**/.git/objects/**" = $true
        "**/.git/subtree-cache/**" = $true
        "**/node_modules/**" = $true
        "**/.hg/store/**" = $true
        "**/test-data/**" = $true
    }
    
    # Auto Save for Git Workflows
    "files.autoSave" = "afterDelay"
    "files.autoSaveDelay" = 1000
    
    # Terminal Integration
    "terminal.integrated.defaultProfile.windows" = "PowerShell"
    "terminal.integrated.profiles.windows" = @{
        "PowerShell" = @{
            "source" = "PowerShell"
            "icon" = "terminal-powershell"
            "args" = @("-ExecutionPolicy", "Bypass")
        }
    }
    
    # GitZoom Specific Settings
    "gitzoom.enableLightningPush" = $true
    "gitzoom.autoStageOnCommit" = $true
    "gitzoom.parallelOperations" = $true
    "gitzoom.smartCaching" = $true
    "gitzoom.predictiveStaging" = $true
}

$experimentalKeybindings = @(
    @{
        "key" = "ctrl+shift+g ctrl+shift+z"
        "command" = "workbench.view.scm"
        "when" = "!terminalFocus"
    },
    @{
        "key" = "ctrl+shift+g ctrl+shift+a"
        "command" = "git.stageAll"
        "when" = "!terminalFocus"
    },
    @{
        "key" = "ctrl+shift+g ctrl+shift+c"
        "command" = "git.commitStaged"
        "when" = "!terminalFocus"
    },
    @{
        "key" = "ctrl+shift+g ctrl+shift+p"
        "command" = "git.push"
        "when" = "!terminalFocus"
    },
    @{
        "key" = "ctrl+shift+g ctrl+shift+s"
        "command" = "git.sync"
        "when" = "!terminalFocus"
    },
    @{
        "key" = "ctrl+shift+g ctrl+shift+l"
        "command" = "workbench.action.terminal.sendSequence"
        "args" = @{
            "text" = "zoom '${input:commitMessage}'\u000D"
        }
        "when" = "terminalFocus"
    },
    @{
        "key" = "ctrl+alt+z"
        "command" = "workbench.action.terminal.sendSequence"
        "args" = @{
            "text" = "zoom 'Quick update'\u000D"
        }
    }
)

# Input variables for VS Code commands
$inputVariables = @{
    "inputs" = @(
        @{
            "id" = "commitMessage"
            "description" = "Enter commit message"
            "default" = "Quick update"
            "type" = "promptString"
        }
    )
}

# ============================================================================
# OPTIMIZATION FUNCTIONS
# ============================================================================

function Test-GitPerformanceSettings {
    Write-Host "`n⚡ Testing Git Performance Settings..." -ForegroundColor Cyan
    
    $settingsPath = "$env:APPDATA\Code\User\settings.json"
    $backupPath = "$env:APPDATA\Code\User\settings.backup.json"
    
    # Backup current settings
    if (Test-Path $settingsPath) {
        Copy-Item $settingsPath $backupPath -Force
        Write-Host "✅ Current settings backed up" -ForegroundColor Green
    }
    
    # Create test settings
    $testSettings = @{}
    if (Test-Path $settingsPath) {
        $current = Get-Content $settingsPath -Raw | ConvertFrom-Json
        $current.PSObject.Properties | ForEach-Object {
            $testSettings[$_.Name] = $_.Value
        }
    }
    
    # Add experimental settings
    $experimentalSettings.GetEnumerator() | ForEach-Object {
        $testSettings[$_.Key] = $_.Value
    }
    
    # Save experimental settings
    $testSettings | ConvertTo-Json -Depth 10 | Out-File $settingsPath -Encoding UTF8
    Write-Host "✅ Experimental settings applied" -ForegroundColor Green
    
    # Test performance
    Write-Host "`n📊 Performance Tests:" -ForegroundColor Yellow
    
    # Test 1: Git status speed
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $status = git status --porcelain 2>$null
    $stopwatch.Stop()
    Write-Host "  Git Status: $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor White
    
    # Test 2: Auto-fetch simulation
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    git fetch --dry-run 2>$null | Out-Null
    $stopwatch.Stop()
    Write-Host "  Auto-fetch: $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor White
    
    return @{
        SettingsApplied = $true
        BackupCreated = (Test-Path $backupPath)
        PerformanceResults = @{
            GitStatus = $stopwatch.ElapsedMilliseconds
        }
    }
}

function Test-KeybindingOptimizations {
    Write-Host "`n⌨️ Testing Keybinding Optimizations..." -ForegroundColor Cyan
    
    $keybindingsPath = "$env:APPDATA\Code\User\keybindings.json"
    $backupPath = "$env:APPDATA\Code\User\keybindings.backup.json"
    
    # Backup current keybindings
    if (Test-Path $keybindingsPath) {
        Copy-Item $keybindingsPath $backupPath -Force
        Write-Host "✅ Current keybindings backed up" -ForegroundColor Green
    }
    
    # Create optimized keybindings
    $experimentalKeybindings | ConvertTo-Json -Depth 10 | Out-File $keybindingsPath -Encoding UTF8
    Write-Host "✅ Experimental keybindings applied" -ForegroundColor Green
    
    # Display keybinding summary
    Write-Host "`n⌨️ GitZoom Keyboard Shortcuts:" -ForegroundColor Yellow
    Write-Host "  Ctrl+Shift+G, Ctrl+Shift+Z  →  Open Git panel" -ForegroundColor White
    Write-Host "  Ctrl+Shift+G, Ctrl+Shift+A  →  Stage all files" -ForegroundColor White
    Write-Host "  Ctrl+Shift+G, Ctrl+Shift+C  →  Commit staged" -ForegroundColor White
    Write-Host "  Ctrl+Shift+G, Ctrl+Shift+P  →  Push to remote" -ForegroundColor White
    Write-Host "  Ctrl+Shift+G, Ctrl+Shift+S  →  Sync (pull+push)" -ForegroundColor White
    Write-Host "  Ctrl+Alt+Z                   →  Lightning push" -ForegroundColor White
    
    return @{
        KeybindingsApplied = $true
        BackupCreated = (Test-Path $backupPath)
        ShortcutCount = $experimentalKeybindings.Count
    }
}

function Test-WorkspaceOptimizations {
    Write-Host "`n📁 Testing Workspace Optimizations..." -ForegroundColor Cyan
    
    $workspaceConfig = @{
        "folders" = @(
            @{
                "path" = "."
            }
        )
        "settings" = @{
            # Workspace-specific Git settings
            "git.enabled" = $true
            "git.showUntracked" = $true
            "git.showUntrackedFiles" = $true
            
            # GitZoom workspace settings
            "gitzoom.projectType" = "auto-detect"
            "gitzoom.optimization.level" = "aggressive"
            "gitzoom.telemetry.enabled" = $true
            
            # File associations for better Git workflows
            "files.associations" = @{
                "*.gitignore" = "ignore"
                "*.gitattributes" = "gitattributes"
                "COMMIT_EDITMSG" = "git-commit"
            }
            
            # Search exclusions for better performance
            "search.exclude" = @{
                "**/.git" = $true
                "**/node_modules" = $true
                "**/test-data" = $true
                "**/*.log" = $true
            }
        }
        "extensions" = @{
            "recommendations" = @(
                "mhutchie.git-graph",
                "eamodio.gitlens",
                "ms-vscode.powershell"
            )
        }
    }
    
    # Save workspace configuration
    $workspaceConfig | ConvertTo-Json -Depth 10 | Out-File "gitzoom.code-workspace" -Encoding UTF8
    Write-Host "✅ Workspace configuration created" -ForegroundColor Green
    
    return @{
        WorkspaceCreated = $true
        ConfigPath = (Get-Item "gitzoom.code-workspace").FullName
    }
}

function Create-OptimizedTasks {
    Write-Host "`n🛠️ Creating Optimized Tasks..." -ForegroundColor Cyan
    
    $vscodePath = ".vscode"
    if (!(Test-Path $vscodePath)) {
        New-Item -ItemType Directory -Path $vscodePath -Force | Out-Null
    }
    
    $tasks = @{
        "version" = "2.0.0"
        "tasks" = @(
            @{
                "label" = "GitZoom: Lightning Push"
                "type" = "shell"
                "command" = "pwsh"
                "args" = @("-ExecutionPolicy", "Bypass", "-File", "scripts/lightning-push.ps1", "-message", "`${input:commitMessage}")
                "group" = "build"
                "presentation" = @{
                    "echo" = $true
                    "reveal" = "always"
                    "focus" = $false
                    "panel" = "shared"
                    "showReuseMessage" = $true
                    "clear" = $false
                }
                "problemMatcher" = @()
            },
            @{
                "label" = "GitZoom: Performance Benchmark"
                "type" = "shell"
                "command" = "pwsh"
                "args" = @("-ExecutionPolicy", "Bypass", "-File", "experiments/performance-benchmark.ps1", "-GenerateReport")
                "group" = "test"
                "presentation" = @{
                    "echo" = $true
                    "reveal" = "always"
                    "focus" = $false
                    "panel" = "shared"
                }
            },
            @{
                "label" = "GitZoom: Generate Test Data"
                "type" = "shell"
                "command" = "pwsh"
                "args" = @("-ExecutionPolicy", "Bypass", "-File", "experiments/test-data-generator.ps1")
                "group" = "build"
                "presentation" = @{
                    "echo" = $true
                    "reveal" = "always"
                }
            },
            @{
                "label" = "GitZoom: Optimization Experiments"
                "type" = "shell"
                "command" = "pwsh"
                "args" = @("-ExecutionPolicy", "Bypass", "-File", "experiments/optimization-experiments.ps1")
                "group" = "test"
                "presentation" = @{
                    "echo" = $true
                    "reveal" = "always"
                }
            }
        )
        "inputs" = @(
            @{
                "id" = "commitMessage"
                "description" = "Enter commit message for GitZoom Lightning Push"
                "default" = "Quick update"
                "type" = "promptString"
            }
        )
    }
    
    $tasks | ConvertTo-Json -Depth 10 | Out-File ".vscode/tasks.json" -Encoding UTF8
    Write-Host "✅ VS Code tasks created" -ForegroundColor Green
    
    return @{
        TasksCreated = $true
        TaskCount = $tasks.tasks.Count
        TasksPath = (Get-Item ".vscode/tasks.json").FullName
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

if ($ResetToDefaults) {
    Write-Host "🔄 Resetting VS Code settings to defaults..." -ForegroundColor Yellow
    
    $settingsBackup = "$env:APPDATA\Code\User\settings.backup.json"
    $keybindingsBackup = "$env:APPDATA\Code\User\keybindings.backup.json"
    
    if (Test-Path $settingsBackup) {
        Copy-Item $settingsBackup "$env:APPDATA\Code\User\settings.json" -Force
        Write-Host "✅ Settings restored from backup" -ForegroundColor Green
    }
    
    if (Test-Path $keybindingsBackup) {
        Copy-Item $keybindingsBackup "$env:APPDATA\Code\User\keybindings.json" -Force
        Write-Host "✅ Keybindings restored from backup" -ForegroundColor Green
    }
    
    exit 0
}

Write-Host "🚀 Starting VS Code integration optimizations..." -ForegroundColor Yellow

$results = @()

switch ($ConfigType.ToLower()) {
    "settings" { $results += Test-GitPerformanceSettings }
    "keybindings" { $results += Test-KeybindingOptimizations }
    "workspace" { $results += Test-WorkspaceOptimizations }
    "tasks" { $results += Create-OptimizedTasks }
    "all" {
        $results += Test-GitPerformanceSettings
        $results += Test-KeybindingOptimizations  
        $results += Test-WorkspaceOptimizations
        $results += Create-OptimizedTasks
    }
}

# ============================================================================
# RESULTS AND RECOMMENDATIONS
# ============================================================================

Write-Host "`n📊 VS CODE OPTIMIZATION RESULTS" -ForegroundColor Magenta
Write-Host "=" * 50 -ForegroundColor Gray

Write-Host "`n✅ Optimizations Applied:" -ForegroundColor Green
Write-Host "  • Enhanced Git performance settings" -ForegroundColor White
Write-Host "  • Optimized keyboard shortcuts for GitZoom" -ForegroundColor White
Write-Host "  • Workspace configuration for better Git workflows" -ForegroundColor White
Write-Host "  • Custom tasks for GitZoom operations" -ForegroundColor White

Write-Host "`n⚡ Performance Improvements:" -ForegroundColor Cyan
Write-Host "  • Auto-fetch every 30 seconds (background sync)" -ForegroundColor White
Write-Host "  • Smart commit staging enabled" -ForegroundColor White
Write-Host "  • Reduced file watching overhead" -ForegroundColor White
Write-Host "  • Optimized terminal integration" -ForegroundColor White

Write-Host "`n🎯 Next Steps:" -ForegroundColor Magenta
Write-Host "1. Restart VS Code to apply all settings" -ForegroundColor White
Write-Host "2. Test keyboard shortcuts with Ctrl+Shift+G combinations" -ForegroundColor White
Write-Host "3. Run 'GitZoom: Performance Benchmark' task to measure improvements" -ForegroundColor White
Write-Host "4. Open the GitZoom workspace file for project-specific optimizations" -ForegroundColor White
Write-Host "5. Monitor daily workflow improvements and adjust settings" -ForegroundColor White

Write-Host "`n💡 Pro Tips:" -ForegroundColor Yellow
Write-Host "  • Use Ctrl+Alt+Z for instant lightning push" -ForegroundColor White
Write-Host "  • Access GitZoom tasks via Ctrl+Shift+P → 'Tasks: Run Task'" -ForegroundColor White
Write-Host "  • Check auto-fetch status in bottom status bar" -ForegroundColor White
Write-Host "  • Use workspace file for team-shared GitZoom settings" -ForegroundColor White

Write-Host "`n✨ VS Code optimization completed!" -ForegroundColor Green