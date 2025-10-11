#!/usr/bin/env node
const { execSync, exec } = require('child_process');
const path = require('path');

function usage() {
  console.log('gitzoom run <experiment.ps1> [--format=json|human]');
  console.log('gitzoom recommend [--format=json|human]');
}

(async () => {
  const args = process.argv.slice(2);
  if (args.length === 0) { usage(); process.exit(0); }

  const cmd = args[0];
  const formatFlagIndex = args.indexOf('--format');
  let format = 'human';
  if (formatFlagIndex !== -1 && args[formatFlagIndex+1]) format = args[formatFlagIndex+1];

  if (cmd === 'run') {
    const script = args[1];
    if (!script) { usage(); process.exit(1); }
    const absolute = path.resolve(script);
    const start = Date.now();
    try {
      execSync(`pwsh -NoProfile -ExecutionPolicy Bypass -File "${absolute}"`, { stdio: 'inherit' });
      const meta = { command: 'run', script: script, exitCode: 0, durationMs: Date.now() - start };
      if (format === 'json') console.log(JSON.stringify({ metadata: meta }, null, 2));
    } catch (e) {
      const meta = { command: 'run', script: script, exitCode: e.status || 1, durationMs: Date.now() - start };
      if (format === 'json') console.log(JSON.stringify({ metadata: meta }, null, 2));
      process.exit(e.status || 1);
    }
  } else if (cmd === 'recommend') {
    const sub = args[1] || 'list';
    const workspaceRoot = process.cwd();

    function scanRecs() {
      const stdout = execSync('git config --list', { encoding: 'utf8' });
      const configs = stdout.split(/\r?\n/).filter(Boolean);
      const hasUntracked = configs.some(c => c.startsWith('core.untrackedCache='));
      const hasFscache = configs.some(c => c.startsWith('core.fscache='));
      const recs = [];
      if (!hasUntracked) recs.push({ key: 'core.untrackedCache', value: 'true', reason: 'Speeds up staging by caching untracked files.' });
      if (!hasFscache) recs.push({ key: 'core.fscache', value: 'true', reason: 'Improves IO performance on supported platforms.' });
      return recs;
    }

    if (sub === 'list') {
      try {
        const recs = scanRecs();
        const metadata = { command: 'recommend', recommendations: recs, timestamp: new Date().toISOString() };
        if (format === 'json') console.log(JSON.stringify(metadata, null, 2));
        else {
          if (recs.length === 0) console.log('No low-risk recommendations.');
          else { recs.forEach(r => console.log(`- ${r.key} = ${r.value}: ${r.reason}`)); }
        }
      } catch (e) { console.error('Failed to run recommend: ', e.message); process.exit(1); }
    } else if (sub === 'apply') {
      const dryRun = args.includes('--dry-run') || args.includes('-n');
      try {
        const recs = scanRecs();
        if (recs.length === 0) { console.log('No recommendations to apply.'); process.exit(0); }

        // prepare backups dir
        const fs = require('fs');
        const backupsDir = path.join(workspaceRoot, '.gitzoom', 'backups');
        if (!fs.existsSync(path.join(workspaceRoot, '.gitzoom'))) fs.mkdirSync(path.join(workspaceRoot, '.gitzoom'));
        if (!fs.existsSync(backupsDir)) fs.mkdirSync(backupsDir, { recursive: true });
        const prev = {};
        for (const r of recs) {
          try { prev[r.key] = execSync(`git config --get ${r.key}`, { encoding: 'utf8' }).trim(); } catch (e) { prev[r.key] = null; }
        }
        const backupId = `backup-${Date.now()}`;
        const backupFile = path.join(backupsDir, `${backupId}.json`);
        fs.writeFileSync(backupFile, JSON.stringify({ timestamp: new Date().toISOString(), prev }, null, 2), 'utf8');
        console.log('Backup written to', backupFile);

        for (const r of recs) {
          const cmdStr = `git config ${r.key} ${r.value}`;
          if (dryRun) { console.log('[dry-run]', cmdStr); continue; }
          try { execSync(cmdStr, { stdio: 'inherit' }); console.log('Applied', r.key); } catch (e) { console.error('Failed to apply', r.key, e.message); }
        }
      } catch (e) { console.error('Failed to apply recommendations: ', e.message); process.exit(1); }
    } else if (sub === 'rollback') {
      // list backups and interactively pick one
      const fs = require('fs');
      const backupsDir = path.join(workspaceRoot, '.gitzoom', 'backups');
      if (!fs.existsSync(backupsDir)) { console.log('No backups found.'); process.exit(0); }
      const files = fs.readdirSync(backupsDir).filter(f => f.endsWith('.json'));
      if (files.length === 0) { console.log('No backups found.'); process.exit(0); }
      console.log('Available backups:');
      files.forEach((f, i) => console.log(`${i+1}) ${f}`));
      // simple stdin prompt to avoid external deps
      function ask(question) {
        return new Promise((resolve) => {
          process.stdout.write(question);
          process.stdin.resume();
          process.stdin.setEncoding('utf8');
          process.stdin.once('data', function(data) {
            process.stdin.pause();
            resolve(data.toString().trim());
          });
        });
      }
      const sel = await ask('Select backup number to restore: ');
      const idx = parseInt(sel, 10) - 1;
      if (isNaN(idx) || idx < 0 || idx >= files.length) { console.log('Invalid selection'); process.exit(1); }
      const backupFile = path.join(backupsDir, files[idx]);
      let data;
      try { data = JSON.parse(fs.readFileSync(backupFile, 'utf8')); } catch (e) { console.error('Failed to read backup:', e.message); process.exit(1); }
      const prev = data.prev || {};
      const keys = Object.keys(prev);
      for (const k of keys) {
        const v = prev[k];
        try {
          if (v === null || v === undefined || v === '') execSync(`git config --unset ${k}`);
          else execSync(`git config ${k} "${v}"`);
          console.log('Restored', k);
        } catch (e) { console.error('Failed to restore', k, e.message); }
      }
      console.log('Restore complete');
    } else {
      console.log('Unknown recommend subcommand. Use: list | apply | rollback');
      process.exit(1);
    }
  } else { usage(); process.exit(1); }
})();
