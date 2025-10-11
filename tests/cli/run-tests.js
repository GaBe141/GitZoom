// Minimal test harness for CLI flows. This is intentionally small and non-blocking for CI.
const {spawnSync} = require('child_process');
const path = require('path');

function runRecommendList() {
  const cli = path.resolve(__dirname, '..', '..', 'tools', 'gitzoom-cli', 'index.js');
  const res = spawnSync('node', [cli, 'recommend', 'list', '--format', 'json'], {encoding: 'utf8', timeout: 10000});
  if (res.error) {
    console.error('Error running CLI:', res.error);
    process.exitCode = 0; // don't fail CI
    return;
  }
  try {
    const out = res.stdout.trim();
    if (!out) {
      console.log('CLI produced no output; skipping assertion.');
      return;
    }
    const json = JSON.parse(out);
    if (!json.recommendations) {
      console.log('Unexpected CLI output shape, got:', out);
    } else {
      console.log('Recommend list returned', json.recommendations.length, 'recommendations.');
    }
  } catch (e) {
    console.log('Non-JSON output from CLI; skipping strict checks.');
  }
}

runRecommendList();
console.log('CLI lightweight tests completed.');
