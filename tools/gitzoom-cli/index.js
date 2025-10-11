#!/usr/bin/env node
const { execSync, exec } = require('child_process');
const path = require('path');

function usage() {
  console.log('gitzoom run <experiment.ps1> [--format=json|human]');
  console.log('gitzoom recommend [--format=json|human]');
}

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
  try {
    const stdout = execSync('git config --list', { encoding: 'utf8' });
    const configs = stdout.split(/\r?\n/).filter(Boolean);
    const hasUntracked = configs.some(c => c.startsWith('core.untrackedCache='));
    const hasFscache = configs.some(c => c.startsWith('core.fscache='));
    const recs = [];
    if (!hasUntracked) recs.push({ key: 'core.untrackedCache', value: 'true', reason: 'Speeds up staging by caching untracked files.' });
    if (!hasFscache) recs.push({ key: 'core.fscache', value: 'true', reason: 'Improves IO performance on supported platforms.' });
    const metadata = { command: 'recommend', recommendations: recs, timestamp: new Date().toISOString() };
    if (format === 'json') console.log(JSON.stringify(metadata, null, 2));
    else {
      if (recs.length === 0) console.log('No low-risk recommendations.');
      else { recs.forEach(r => console.log(`- ${r.key} = ${r.value}: ${r.reason}`)); }
    }
  } catch (e) {
    console.error('Failed to run recommend: ', e.message);
    process.exit(1);
  }
} else { usage(); process.exit(1); }
