// Re-run the existing checks and retain the output used by the technical report.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { spawnSync } = require('child_process');
const root = path.resolve(__dirname, '..');
const app = path.join(root, 'quickapp/focusloop');
const stamp = new Date().toISOString();
let out = path.join(root, 'docs/verification', stamp.slice(0, 10));
if (fs.existsSync(out)) out += '-' + stamp.slice(11, 23).replace(/[:.]/g, '');
fs.mkdirSync(out, { recursive: true });
const hash = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const runs = [];
function run(name, command, args) {
  const start = process.hrtime.bigint();
  const result = spawnSync(command, args, { cwd: app, encoding: 'utf8', timeout: 180000 });
  const elapsedMs = Number(process.hrtime.bigint() - start) / 1e6;
  const output = ((result.stdout || '') + (result.stderr || ''))
    .replace(/\x1b\[[0-9;]*m/g, '').split(root).join('${REPO_ROOT}')
    .split(root.replace(/\\/g, '/')).join('${REPO_ROOT}');
  if (result.error) throw result.error;
  fs.writeFileSync(path.join(out, name + '.txt'), output, 'utf8');
  const row = { name, command: command === process.execPath ? 'node' : command,
    args, exitCode: result.status, elapsedMs: Math.round(elapsedMs),
    output: name + '.txt', outputSha256: hash(path.join(out, name + '.txt')) };
  if (name.startsWith('test-')) {
    row.testsPassed = Number((output.match(/(\d+) tests passed/) || [])[1] || 0);
    if (row.testsPassed !== 28) throw new Error('Unexpected test count');
  }
  runs.push(row);
  if (result.status !== 0) throw new Error(name + ' failed: ' + result.status);
  console.log(name + ': passed (' + row.elapsedMs + ' ms)');
}
for (let i = 1; i <= 20; i++) run('test-' + String(i).padStart(2, '0'), process.execPath, ['test/run.js']);
const npm = args => process.platform === 'win32'
  ? ['cmd.exe', ['/d', '/s', '/c', 'npm ' + args]] : ['npm', args.split(' ')];
for (let i = 1; i <= 5; i++) run('build-' + i, ...npm('run build'));
run('audit-production', ...npm('audit --omit=dev --json'));
const rpk = path.join(root, 'artifacts/FocusLoop-0.1.0-debug.rpk');
const summary = { capturedAt: new Date().toISOString(),
  sourceCommit: spawnSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).stdout.trim(),
  sourceTree: spawnSync('git', ['rev-parse', 'HEAD^{tree}'], { cwd: root, encoding: 'utf8' }).stdout.trim(),
  node: process.version, platform: process.platform, arch: process.arch,
  toolkit: require(path.join(app, 'node_modules/aiot-toolkit/package.json')).version,
  scope: 'Host logic/structural tests and QuickApp builds. No hardware, ASR, model latency or battery measurements.',
  testsPerRound: 28, testRounds: 20, totalChecks: 560, buildRounds: 5,
  submittedRpk: { path: 'artifacts/FocusLoop-0.1.0-debug.rpk', bytes: fs.statSync(rpk).size, sha256: hash(rpk) },
  runs };
fs.writeFileSync(path.join(out, 'summary.json'), JSON.stringify(summary, null, 2) + '\n');
console.log('Evidence: ' + path.relative(root, out));
