// Local verification only. This script never deploys or changes production data.
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '..');
const args = process.argv.slice(2);
const sdkOption = args.indexOf('--flutter-sdk');
const sdk = sdkOption < 0 ? process.env.FLUTTER_ROOT : args[sdkOption + 1];
if (Number(process.versions.node.split('.')[0]) !== 24) throw Error('Verification requires Node.js 24, matching deployment.');
if (!sdk) throw Error('Set FLUTTER_ROOT or pass --flutter-sdk <Flutter SDK directory>.');
const dart = path.join(sdk, 'bin/cache/dart-sdk/bin', process.platform === 'win32' ? 'dart.exe' : 'dart');
const toolArgs = [`--packages=${path.join(sdk, 'packages/flutter_tools/.dart_tool/package_config.json')}`, path.join(sdk, 'bin/cache/flutter_tools.snapshot')];
for (const file of [dart, toolArgs[1]]) if (!fs.existsSync(file)) throw Error(`Flutter tool is missing: ${file}`);
function run(command, parameters, cwd = root) {
  console.log(`\n> ${path.basename(command)} ${parameters.join(' ')}`);
  const env = {...process.env, CI: 'true', FLUTTER_ROOT: path.resolve(sdk)};
  // Emulator commands also launch `node`; keep them on this verified runtime.
  const pathKey = Object.keys(env).find(key => key.toUpperCase() === 'PATH') ?? 'PATH';
  env[pathKey] = path.dirname(process.execPath) + path.delimiter + (env[pathKey] ?? '');
  const result = spawnSync(command, parameters, {cwd, stdio: 'inherit', env});
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}
const node = (...parameters) => run(process.execPath, parameters);
const flutter = (...parameters) => run(dart, [...toolArgs, ...parameters]);
node('scripts/verify_generated.cjs');
run(process.execPath, ['node_modules/eslint/bin/eslint.js', '.'], path.join(root, 'functions'));
node('--test', 'functions/test/*.test.js');
flutter('analyze', '--no-pub');
flutter('test', '--no-pub', '--reporter', 'expanded');
if (args.includes('--release')) {
  run(dart, ['tools/maintenance/chrome_test_runner.dart', path.resolve(sdk),
    'test/screens/mobile_input_test.dart', 'test/screens/mobile_layout_test.dart',
    'test/screens/mobile_flow_completion_test.dart',
    'test/screens/onboarding/onboarding_screen_test.dart',
    'test/widgets/home_screen_test.dart',
    'test/features/chat/communication_photo_test.dart',
    'test/screens/pet_communication_credit_test.dart',
    'test/features/chat/pet_planet_navigation_test.dart',
    'test/features/chat/planet_award_test.dart',
    'test/features/journal_m1_test.dart', 'test/features/journal_m23_test.dart',
    'test/features/pilot_m4_test.dart', 'test/features/pilot_wire_mapper_test.dart']);
  node('scripts/build_hosting.cjs', '--flutter-sdk', path.resolve(sdk));
}
if (args.includes('--emulators')) {
  node('scripts/package_knowledge.cjs');
  node('tools/security/apply-security-patches.cjs');
  node('--test', 'tools/security/dependency-security.test.cjs');
  const cli = 'tools/security/node_modules/firebase-tools/lib/bin/firebase.js';
  run(process.execPath, [cli, 'emulators:exec', '--config', 'firebase.security.json',
    '--project', 'demo-pawlink-security', '--only', 'firestore,storage',
    'node --test tools/security/rules.test.cjs']);
  for (const suite of ['journal', 'journal-m23', 'journal-m4', 'communication-photos']) {
    run(process.execPath, [cli, 'emulators:exec', '--config', 'firebase.journal-test.json',
      '--project', 'demo-pawlink-security', '--only', 'auth,firestore,storage,functions',
      `node --test tools/security/${suite}.test.cjs`]);
  }
}
console.log('\nAll requested local check commands completed. Review test output for skipped cases. No deployment performed.');
