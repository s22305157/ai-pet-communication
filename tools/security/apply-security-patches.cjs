'use strict';

// Apply reviewed, version- and SHA-256-locked backports. No network or shell.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = __dirname;
const sha = text => crypto.createHash('sha256').update(text).digest('hex');
const manifest = require('./patches/manifest.json');
const changes = [];
for (const patch of manifest) {
  const base = path.join(root, 'node_modules', patch.package);
  const version = JSON.parse(fs.readFileSync(path.join(base, 'package.json'))).version;
  if (version !== patch.version) throw new Error(`Review security backport for ${patch.package}@${version}`);
  for (const file of patch.files) {
    const target = path.join(base, file.path);
    const original = fs.readFileSync(target, 'utf8').replace(/\r\n/g, '\n');
    if (sha(original) === file.afterSha256) continue;
    if (sha(original) !== file.beforeSha256) throw new Error(`Unexpected dependency contents: ${target}`);
    let result = original;
    for (const edit of file.edits) {
      if (result.split(edit.before).length !== 2) throw new Error(`Ambiguous patch: ${target}`);
      result = result.replace(edit.before, edit.after);
    }
    if (sha(result) !== file.afterSha256) throw new Error(`Patch integrity failure: ${target}`);
    changes.push([target, result]);
  }
}
// Validate every target before modifying any file. Re-running is safe.
for (const [target, result] of changes) fs.writeFileSync(target, result);
console.log(`Security backports verified; ${changes.length} file(s) patched.`);
