import * as vscode from 'vscode';
import { exec, execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

export function activate(context: vscode.ExtensionContext) {
    const output = vscode.window.createOutputChannel('GitZoom Experiments');
    const statusBar = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
    statusBar.command = 'gitzoom.openRecommendationsMenu';
    statusBar.text = '$(rocket) GitZoom: scanning...';
    statusBar.tooltip = 'GitZoom: scanning for staging recommendations';
    statusBar.show();

    const runExperiment = vscode.commands.registerCommand('gitzoom.runExperiment', async () => {
        // Auto-discover experiment scripts under the workspace experiments/ folder
        const workspaceRoot = vscode.workspace.workspaceFolders?.[0].uri;
        if (!workspaceRoot) {
            vscode.window.showErrorMessage('Open a workspace to run GitZoom experiments.');
            return;
        }

    const config = vscode.workspace.getConfiguration('gitzoom');
    const globPattern = config.get<string>('experiments.glob', 'experiments/**/*.ps1');
    const pwshPath = config.get<string>('pwshPath', 'pwsh');
    const files = await vscode.workspace.findFiles(globPattern, '**/node_modules/**');
        if (!files || files.length === 0) {
            vscode.window.showInformationMessage('No experiment scripts found in the workspace `experiments/` folder.');
            return;
        }

        const items = files.map(f => ({ label: vscode.workspace.asRelativePath(f), uri: f }));
        const pick = await vscode.window.showQuickPick(items, { placeHolder: 'Select an experiment to run' });
        if (!pick) { return; }

        const choicePath = pick.uri.fsPath;
        output.show(true);
        output.appendLine(`Running experiment: ${vscode.workspace.asRelativePath(pick.uri)}`);

    const command = `${pwshPath} -NoProfile -ExecutionPolicy Bypass -File "${choicePath}"`;
        const proc = exec(command, { cwd: workspaceRoot.fsPath });

        proc.stdout?.on('data', (data) => output.append(data.toString()));
        proc.stderr?.on('data', (data) => output.append(data.toString()));

        proc.on('close', (code) => {
            output.appendLine(`\nExperiment finished with code ${code}`);
        });
    });

    context.subscriptions.push(runExperiment);

    const recommendOptimization = vscode.commands.registerCommand('gitzoom.recommendOptimization', async () => {
        const workspaceRoot = vscode.workspace.workspaceFolders?.[0].uri.fsPath;
        if (!workspaceRoot) {
            vscode.window.showErrorMessage('Open a workspace to run GitZoom recommendations.');
            return;
        }

        // Simple heuristic: recommend core.untrackedCache and core.fscache if not set
        const output = vscode.window.createOutputChannel('GitZoom Recommendations');
        output.show(true);
    const configSettings = vscode.workspace.getConfiguration('gitzoom');
    const enableRecommendations = configSettings.get<boolean>('recommendations.enable', true);
    const dryRun = configSettings.get<boolean>('dryRun', false);

    output.appendLine('Scanning repository for low-risk staging optimizations...');

        // Check current git configs
    exec('git config --list', { cwd: workspaceRoot }, (err: any, stdout: string, stderr: string) => {
            if (err) {
                output.appendLine('Failed to read git config: ' + (stderr || err.message));
                return;
            }

            const configs = stdout.split(/\r?\n/).filter(Boolean);
            const hasUntracked = configs.some((c: string) => c.startsWith('core.untrackedCache='));
            const hasFscache = configs.some((c: string) => c.startsWith('core.fscache='));

            const recommendations: Array<{key:string,value:string,reason:string}> = [];
            if (!hasUntracked) { recommendations.push({ key: 'core.untrackedCache', value: 'true', reason: 'Speeds up staging by caching untracked files.' }); }
            if (!hasFscache) { recommendations.push({ key: 'core.fscache', value: 'true', reason: 'Improves IO performance on supported platforms.' }); }

            if (recommendations.length === 0) {
                output.appendLine('No low-risk staging recommendations detected.');
                return;
            }

            output.appendLine('\nRecommendations:');
            recommendations.forEach((r) => output.appendLine(`- ${r.key} = ${r.value}: ${r.reason}`));

            if (!enableRecommendations) { output.appendLine('Recommendations are disabled via settings.'); return; }

            vscode.window.showInformationMessage('Apply recommended staging optimizations?', 'Apply', 'Ignore').then(async (choice) => {
                if (choice !== 'Apply') { output.appendLine('User ignored recommendations.'); return; }

                // Prepare backup folder
                const gitzoomDir = path.join(workspaceRoot, '.gitzoom');
                if (!fs.existsSync(gitzoomDir)) { fs.mkdirSync(gitzoomDir); }
                const backupsDir = path.join(gitzoomDir, 'backups');
                if (!fs.existsSync(backupsDir)) { fs.mkdirSync(backupsDir); }
                const backupId = `backup-${Date.now()}`;
                const backupFile = path.join(backupsDir, `${backupId}.json`);

                // Read current values and store backup
                const prev = {};
                for (const r of recommendations) {
                    try {
                        const val = execSync(`git config --get ${r.key}`, { cwd: workspaceRoot, encoding: 'utf8' }).trim();
                        prev[r.key] = val;
                    } catch (e) { prev[r.key] = null; }
                }
                fs.writeFileSync(backupFile, JSON.stringify({ timestamp: new Date().toISOString(), prev }, null, 2), 'utf8');
                output.appendLine(`Backup written to ${backupFile}`);

                // Apply recommendations (dry-run support)
                for (const r of recommendations) {
                    const cmd = `git config ${r.key} ${r.value}`;
                    if (dryRun) {
                        output.appendLine(`[dry-run] ${cmd}`);
                        continue;
                    }
                    try {
                        execSync(cmd, { cwd: workspaceRoot });
                        output.appendLine(`Applied ${r.key} = ${r.value}`);
                    } catch (e) { output.appendLine(`Failed to set ${r.key}: ${e.message}`); }
                }

                updateStatusBar();
            });
        });
    });

    context.subscriptions.push(recommendOptimization);
    context.subscriptions.push(statusBar);

    // Core recommendation scan function (returns array of recommendations)
    function scanRecommendations(workspaceRoot: string): Promise<Array<{key:string,value:string,reason:string}>> {
        return new Promise((resolve, reject) => {
            exec('git config --list', { cwd: workspaceRoot }, (err: any, stdout: string, stderr: string) => {
                if (err) { return resolve([]); }
                const configs = stdout.split(/\r?\n/).filter(Boolean);
                const hasUntracked = configs.some((c: string) => c.startsWith('core.untrackedCache='));
                const hasFscache = configs.some((c: string) => c.startsWith('core.fscache='));
                const recommendations: Array<{key:string,value:string,reason:string}> = [];
                if (!hasUntracked) { recommendations.push({ key: 'core.untrackedCache', value: 'true', reason: 'Speeds up staging by caching untracked files.' }); }
                if (!hasFscache) { recommendations.push({ key: 'core.fscache', value: 'true', reason: 'Improves IO performance on supported platforms.' }); }
                resolve(recommendations);
            });
        });
    }

    // Helper to update status bar with current recommendation count
    async function updateStatusBar() {
        const workspaceRoot = vscode.workspace.workspaceFolders?.[0].uri.fsPath;
        if (!workspaceRoot) { statusBar.text = 'GitZoom: no workspace'; return; }

        try {
            const recs = await scanRecommendations(workspaceRoot);
            const count = recs.length;
            if (count === 0) {
                statusBar.text = '$(check) GitZoom: no recs';
                statusBar.tooltip = 'No low-risk staging recommendations detected';
                statusBar.color = undefined;
            } else {
                statusBar.text = `$(warning) GitZoom: ${count} recs`;
                statusBar.tooltip = `${count} low-risk staging recommendation(s). Click to review.`;
                statusBar.color = 'yellow';
            }
        } catch (e) {
            statusBar.text = 'GitZoom: error';
        }
    }

    // Update status bar on activation and when workspace changes
    updateStatusBar();
    vscode.workspace.onDidChangeWorkspaceFolders(updateStatusBar);
    vscode.workspace.onDidSaveTextDocument(updateStatusBar);

    // Recommendations menu command (shows details and actions)
    const openRecommendationsMenu = vscode.commands.registerCommand('gitzoom.openRecommendationsMenu', async () => {
        const workspaceRoot = vscode.workspace.workspaceFolders?.[0].uri.fsPath;
        if (!workspaceRoot) { vscode.window.showErrorMessage('Open a workspace to view recommendations.'); return; }

        const recs = await scanRecommendations(workspaceRoot);
        if (!recs || recs.length === 0) { vscode.window.showInformationMessage('No low-risk recommendations found.'); return; }

    type RecommendationQuickPickItem = vscode.QuickPickItem & { r?: {key:string,value:string,reason:string} };
    const pickItems: RecommendationQuickPickItem[] = recs.map(r => ({ label: `${r.key} = ${r.value}`, description: r.reason, r }));
    const applyAllItem: RecommendationQuickPickItem = { label: 'Apply all', description: 'Apply all recommendations' };
    const choice = await vscode.window.showQuickPick([...pickItems, applyAllItem], { placeHolder: 'Recommendations' });
        if (!choice) { return; }

        if (choice.label === 'Apply all') {
            vscode.commands.executeCommand('gitzoom.recommendOptimization');
            updateStatusBar();
            return;
        }

        // Single recommendation action
    const single = choice.r;
    if (!single) { return; }
        const confirm = await vscode.window.showInformationMessage(`Apply ${single.key} = ${single.value}?`, 'Apply', 'Ignore');
        if (confirm !== 'Apply') { return; }
        exec(`git config ${single.key} ${single.value}`, { cwd: workspaceRoot }, (e: any, o: string, se: string) => {
            if (e) { vscode.window.showErrorMessage(`Failed to set ${single.key}: ${se || e.message}`); }
            else { vscode.window.showInformationMessage(`Applied ${single.key} = ${single.value}`); updateStatusBar(); }
        });
    });

    context.subscriptions.push(openRecommendationsMenu);

    // Rollback command - list backups and restore one
    const rollbackRecommendations = vscode.commands.registerCommand('gitzoom.rollbackRecommendations', async () => {
        const workspaceRoot = vscode.workspace.workspaceFolders?.[0].uri.fsPath;
        if (!workspaceRoot) { vscode.window.showErrorMessage('Open a workspace to rollback recommendations.'); return; }

        const backupsDir = path.join(workspaceRoot, '.gitzoom', 'backups');
        if (!fs.existsSync(backupsDir)) { vscode.window.showInformationMessage('No backups found.'); return; }

        const files = fs.readdirSync(backupsDir).filter(f => f.endsWith('.json'));
        if (!files || files.length === 0) { vscode.window.showInformationMessage('No backups found.'); return; }

        const items = files.map(f => ({ label: f, description: f }));
        const pick = await vscode.window.showQuickPick(items, { placeHolder: 'Select a backup to restore' });
        if (!pick) { return; }

        const backupFile = path.join(backupsDir, pick.label);
        let data: any;
        try { data = JSON.parse(fs.readFileSync(backupFile, 'utf8')); } catch (e) { vscode.window.showErrorMessage('Failed to read backup file.'); return; }

        const prev = data.prev || {};
        const keys = Object.keys(prev);
        if (keys.length === 0) { vscode.window.showInformationMessage('Backup has no entries.'); return; }

        const confirm = await vscode.window.showInformationMessage(`Restore ${keys.length} settings from ${pick.label}?`, 'Restore', 'Cancel');
        if (confirm !== 'Restore') { return; }

        // Apply restore: if previous value is null -> unset, else set to previous value
        for (const k of keys) {
            const v = prev[k];
            try {
                if (v === null || v === undefined || v === '') {
                    execSync(`git config --unset ${k}`, { cwd: workspaceRoot });
                    output.appendLine(`Unset ${k}`);
                } else {
                    execSync(`git config ${k} "${v}"`, { cwd: workspaceRoot });
                    output.appendLine(`Restored ${k} = ${v}`);
                }
            } catch (e) {
                output.appendLine(`Failed to restore ${k}: ${e.message}`);
            }
        }

        vscode.window.showInformationMessage(`Restored backup ${pick.label}`);
        updateStatusBar();
    });

    context.subscriptions.push(rollbackRecommendations);
}

export function deactivate() {}
