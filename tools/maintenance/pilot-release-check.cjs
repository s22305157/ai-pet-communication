#!/usr/bin/env node
// Read-only local artifact verification. This does not deploy or certify device QA.
const fs = require('node:fs');
const path = require('node:path');
const {createHash} = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const build = path.join(root, 'build/web');
const expected = fs.readFileSync(path.join(root, 'pubspec.yaml'), 'utf8').match(/^version:\s*([^\s+]+)/m)?.[1];
function check(condition, message) { if (!condition) throw Error(message); }
function files(dir) {
  return fs.readdirSync(dir, {withFileTypes: true}).flatMap(e => e.isDirectory() ? files(path.join(dir, e.name)) : [path.join(dir, e.name)]);
}
try {
  check(expected, 'Missing pubspec version');
  const version = JSON.parse(fs.readFileSync(path.join(build, 'version.json'), 'utf8'));
  check(version.version === expected, 'Compiled version differs from pubspec');
  const artifacts = ['version.json', 'index.html', 'flutter_bootstrap.js', 'main.dart.js'].map(name => {
    const bytes = fs.readFileSync(path.join(build, name));
    return {name, bytes: bytes.length, sha256: createHash('sha256').update(bytes).digest('hex')};
  });
  for (const name of ['index.html', 'flutter_bootstrap.js']) {
    check(fs.readFileSync(path.join(build, name), 'utf8').includes(`release=${expected}`), `${name} cache version mismatch`);
  }
  const main = fs.readFileSync(path.join(build, 'main.dart.js'), 'utf8');
  for (const name of ['getPilotInterest', 'setPilotInterest', 'setPilotMetricsConsent', 'adminGetPilotMetrics', 'adminSetPilotCost']) {
    check(main.includes(name), `M4 callable missing from compiled frontend: ${name}`);
  }
  const internal = /PAWLINK_PRODUCT_BLUEPRINT|JOURNAL_M[234]|試營運開發規畫書|(?:^|[\\/])scratch[\\/]/;
  check(files(build).every(file => !internal.test(path.relative(build, file))), 'Internal document in Hosting output');
  for (const name of ['index.html', 'flutter_bootstrap.js', 'main.dart.js']) {
    check(!internal.test(fs.readFileSync(path.join(build, name), 'utf8')), 'Internal document referenced by public app');
  }
  console.log(JSON.stringify({scope: 'local-build-only', version: expected, verifiedAt: new Date().toISOString(),
    artifacts, internalDocumentsAbsent: true, deploymentPerformed: false, physicalDevicesVerified: false}, null, 2));
} catch (error) { console.error(error.message); process.exitCode = 1; }
