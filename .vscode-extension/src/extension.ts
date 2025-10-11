import * as vscode from 'vscode';
import { exec } from 'child_process';

export function activate(context: vscode.ExtensionContext) {
    const output = vscode.window.createOutputChannel('GitZoom Experiments');
    const statusBar = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
    statusBar.command = 'gitzoom.recommendOptimization';
    statusBar.text = 'GitZoom: scanning...';
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

            vscode.window.showInformationMessage('Apply recommended staging optimizations?', 'Apply', 'Ignore').then((choice) => {
                if (choice !== 'Apply') { output.appendLine('User ignored recommendations.'); return; }

                // Apply recommendations (dry-run support)
                recommendations.forEach((r) => {
                    const cmd = `git config ${r.key} ${r.value}`;
                    if (dryRun) {
                        output.appendLine(`[dry-run] ${cmd}`);
                        return;
                    }

                    exec(cmd, { cwd: workspaceRoot }, (e: any, o: string, se: string) => {
                        if (e) {
                            output.appendLine(`Failed to set ${r.key}: ${se || e.message}`);
                        } else {
                            output.appendLine(`Applied ${r.key} = ${r.value}`);
                        }
                    });
                });
            });
        });
    });

    context.subscriptions.push(recommendOptimization);
    context.subscriptions.push(statusBar);

    // Helper to update status bar with current recommendation count
    async function updateStatusBar() {
        const workspaceRoot = vscode.workspace.workspaceFolders?.[0].uri.fsPath;
        if (!workspaceRoot) { statusBar.text = 'GitZoom: no workspace'; return; }

        try {
            exec('git config --list', { cwd: workspaceRoot }, (err: any, stdout: string, stderr: string) => {
                if (err) { statusBar.text = 'GitZoom: repo error'; return; }
                const configs = stdout.split(/\r?\n/).filter(Boolean);
                const hasUntracked = configs.some((c: string) => c.startsWith('core.untrackedCache='));
                const hasFscache = configs.some((c: string) => c.startsWith('core.fscache='));
                const count = (hasUntracked ? 0 : 1) + (hasFscache ? 0 : 1);
                if (count === 0) {
                    statusBar.text = 'GitZoom: no recs';
                    statusBar.tooltip = 'No low-risk staging recommendations detected';
                    statusBar.color = undefined;
                } else {
                    statusBar.text = `GitZoom: ${count} recs`;
                    statusBar.tooltip = `${count} low-risk staging recommendation(s). Click to review.`;
                    statusBar.color = 'yellow';
                }
            });
        } catch (e) {
            statusBar.text = 'GitZoom: error';
        }
    }

    // Update status bar on activation and when workspace changes
    updateStatusBar();
    vscode.workspace.onDidChangeWorkspaceFolders(updateStatusBar);
    vscode.workspace.onDidSaveTextDocument(updateStatusBar);
}

export function deactivate() {}
