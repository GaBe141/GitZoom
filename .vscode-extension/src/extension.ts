import * as vscode from 'vscode';
import { exec } from 'child_process';

export function activate(context: vscode.ExtensionContext) {
    const output = vscode.window.createOutputChannel('GitZoom Experiments');

    const runExperiment = vscode.commands.registerCommand('gitzoom.runExperiment', async () => {
        const scripts = ['experiments/staging-champion.ps1', 'experiments/adaptive-turbo.ps1'];
        const choice = await vscode.window.showQuickPick(scripts, { placeHolder: 'Select an experiment to run' });
        if (!choice) { return; }

        output.show(true);
        output.appendLine(`Running experiment: ${choice}`);

        const command = `pwsh -NoProfile -ExecutionPolicy Bypass -File "${choice}" -TestStagingChampion`;
        const proc = exec(command, { cwd: vscode.workspace.workspaceFolders?.[0].uri.fsPath });

        proc.stdout?.on('data', (data) => output.append(data.toString()));
        proc.stderr?.on('data', (data) => output.append(data.toString()));

        proc.on('close', (code) => {
            output.appendLine(`\nExperiment finished with code ${code}`);
        });
    });

    context.subscriptions.push(runExperiment);
}

export function deactivate() {}
