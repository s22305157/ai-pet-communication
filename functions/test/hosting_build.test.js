const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {buildHosting} = require('../../scripts/build_hosting.cjs');

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'pawlink-hosting-test-'));
  t.after(() => {
    assert.equal(path.dirname(path.resolve(root)), path.resolve(os.tmpdir()));
    assert.ok(path.basename(root).startsWith('pawlink-hosting-test-'));
    fs.rmSync(root, {recursive: true, force: true});
  });
  const sdk = path.join(root, 'sdk');
  for (const file of ['bin/cache/dart-sdk/bin/dart', 'bin/cache/dart-sdk/bin/dart.exe',
    'bin/cache/flutter_tools.snapshot', 'packages/flutter_tools/.dart_tool/package_config.json']) {
    fs.mkdirSync(path.dirname(path.join(sdk, file)), {recursive: true});
    fs.writeFileSync(path.join(sdk, file), 'fixture');
  }
  return {root, sdk};
}

test('Hosting hook rebuilds changed source with an unchanged version before accepting output', t => {
  const {root, sdk} = fixture(t);
  const bundle = path.join(root, 'bundle');
  const source = path.join(root, 'source');
  fs.writeFileSync(bundle, 'old source, version 0.3.0');
  fs.writeFileSync(source, 'new source, version 0.3.0');
  let builds = 0;
  let checked = false;
  buildHosting({root, sdk, spawn: (command, args) => {
    assert.ok(!args.some(arg => /deploy|firebase/.test(arg)));
    if (args.includes('build')) {
      builds++;
      assert.ok(args.includes('--release'));
      fs.writeFileSync(bundle, fs.readFileSync(source));
    }
    if (args.includes('tools/maintenance/pilot-release-check.cjs')) {
      assert.equal(fs.readFileSync(bundle, 'utf8'), 'new source, version 0.3.0');
      checked = true;
    }
    return {status: 0};
  }});
  assert.equal(builds, 1);
  assert.equal(checked, true);
  const config = require('../../firebase.json');
  assert.deepEqual(config.hosting.predeploy, ['node scripts/build_hosting.cjs']);
});

test('missing SDK, failed build and failed artifact checks block Hosting preparation', t => {
  const {root, sdk} = fixture(t);
  assert.throws(() => buildHosting({sdk: '', spawn: () => assert.fail('must not run')}), /FLUTTER_ROOT/);
  for (const failedStage of ['scripts/verify_generated.cjs', 'build', 'tools/maintenance/pilot-release-check.cjs']) {
    const commands = [];
    assert.throws(() => buildHosting({root, sdk, spawn: (_, args) => {
      commands.push(args);
      return {status: args.includes(failedStage) ? 1 : 0};
    }}), /Hosting preparation failed/);
    assert.ok(commands.at(-1).includes(failedStage));
  }
});
