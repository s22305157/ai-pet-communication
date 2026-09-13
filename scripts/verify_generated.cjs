const path = require('node:path');
const {spawnSync} = require('node:child_process');
for (const script of ['generate_catalog.cjs', 'generate_version.cjs']) {
  const result = spawnSync(process.execPath, [path.join(__dirname, script), '--check'], {stdio: 'inherit'});
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}
