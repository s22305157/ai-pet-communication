// Firebase Hosting predeploy: rebuild the current checkout before checking it.
// This entry point only prepares local artifacts; it never invokes deployment.
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');

function buildHosting({root = path.resolve(__dirname, '..'),
  sdk = process.env.FLUTTER_ROOT, spawn = spawnSync} = {}) {
  if (!sdk) throw Error('Set FLUTTER_ROOT before deploying Hosting; existing build/web is not accepted.');
  sdk = path.resolve(sdk);
  const dart = path.join(sdk, 'bin/cache/dart-sdk/bin', process.platform === 'win32' ? 'dart.exe' : 'dart');
  const snapshot = path.join(sdk, 'bin/cache/flutter_tools.snapshot');
  const packages = path.join(sdk, 'packages/flutter_tools/.dart_tool/package_config.json');
  for (const file of [dart, snapshot, packages]) {
    if (!fs.existsSync(file)) throw Error(`Flutter tool is missing: ${file}`);
  }
  const run = (command, args) => {
    const result = spawn(command, args, {cwd: root, stdio: 'inherit',
      env: {...process.env, CI: 'true', FLUTTER_ROOT: sdk}});
    if (result.error) throw result.error;
    if (result.status !== 0) throw Error(`Hosting preparation failed (${result.status ?? 'signal'}): ${args.join(' ')}`);
  };
  run(process.execPath, ['scripts/verify_generated.cjs']);
  run(dart, [`--packages=${packages}`, snapshot, 'build', 'web', '--release', '--no-pub']);
  run(process.execPath, ['tools/maintenance/pilot-release-check.cjs']);
}

if (require.main === module) {
  const option = process.argv.indexOf('--flutter-sdk');
  try { buildHosting({sdk: option < 0 ? process.env.FLUTTER_ROOT : process.argv[option + 1]}); }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
module.exports = {buildHosting};
