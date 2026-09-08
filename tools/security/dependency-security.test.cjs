'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { Readable, Writable } = require('node:stream');
const { pipeline } = require('node:stream/promises');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { parser } = require('stream-json');
const Stringer = require('stream-json/Stringer');
const api = require('@opentelemetry/api');
const { W3CBaggagePropagator } = require('@opentelemetry/core');
const propagator = new W3CBaggagePropagator();
function entries(header) {
  const context = propagator.extract(api.ROOT_CONTEXT, { baggage: header }, api.defaultTextMapGetter);
  return api.propagation.getBaggage(context)?.getAllEntries() || [];
}
async function filterJson(name, filter, json) {
  const Filter = require(`stream-json/filters/${name}`);
  let output = '';
  await pipeline(Readable.from([json]), parser(), new Filter({ filter }), new Stringer(),
    new Writable({ write(chunk, encoding, callback) { output += chunk; callback(); } }));
  return output;
}
for (const name of ['Pick', 'Ignore', 'Filter', 'Replace']) {
  test(`${name} rejects adversarial depth for string and regex filters`, async () => {
    const json = '['.repeat(1500) + '0' + ']'.repeat(1500);
    for (const filter of ['missing', /^missing$/]) {
      await assert.rejects(filterJson(name, filter, json), /nesting depth exceeds maxDepth/);
    }
  });
}
test('filters retain normal object and array semantics', async () => {
  const json = '{"data":{"items":[1,2]},"other":3}';
  assert.deepEqual(JSON.parse(await filterJson('Pick', 'data', json)), { items: [1, 2] });
  assert.deepEqual(JSON.parse(await filterJson('Filter', /^data/, json)), { data: { items: [1, 2] } });
  assert.deepEqual(JSON.parse(await filterJson('Ignore', 'other', json)), { data: { items: [1, 2] } });
  assert.deepEqual(JSON.parse(await filterJson('Replace', 'other', json)), { data: { items: [1, 2] }, other: null });
});
test('baggage retains valid values, metadata and multiple headers', () => {
  const result = entries(['a=hello%20world;tag', 'b=two']);
  assert.equal(result.length, 2);
  assert.equal(result[0][1].value, 'hello world');
  assert.equal(result[0][1].metadata.toString(), 'tag');
  assert.equal(result[1][1].value, 'two');
});
test('baggage caps accepted entries at 180 across header arrays', () => {
  const headers = Array.from({ length: 10000 }, (_, i) => `k${i}=value`);
  // A join before limiting would allocate the entire attacker-controlled array.
  headers.join = () => { throw new Error('unbounded header join'); };
  assert.equal(entries(headers).length, 180);
});
test('baggage skips entries above 4096 and accepts the exact boundary', () => {
  assert.equal(entries('a=' + 'x'.repeat(4094)).length, 1);
  assert.equal(entries('a=' + 'x'.repeat(4095)).length, 0);
  assert.deepEqual(entries('a=' + 'x'.repeat(1_000_000) + ',b=ok'), [['b', { value: 'ok' }]]);
});
test('baggage enforces the 8192 total including separators', () => {
  const first = 'a=' + 'x'.repeat(4094);
  const second = 'b=' + 'y'.repeat(4093);
  assert.equal(entries([first, second]).length, 2); // 4096 + 1 + 4095
  assert.equal(entries([first, second + 'y']).length, 1);
  assert.equal(entries([first, second, 'c=z']).length, 2);
});
test('empty, malformed and duplicate baggage is handled safely', () => {
  assert.deepEqual(entries(undefined), []);
  assert.deepEqual(entries('bad,%ZZ=invalid'), []);
  assert.deepEqual(entries('a=one,a=two'), [['a', { value: 'two' }]]);
});
test('backport application is reproducible, idempotent and fails on drift', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'pawlink-backport-'));
  try {
    const manifest = require('./patches/manifest.json');
    fs.mkdirSync(path.join(root, 'patches'));
    fs.copyFileSync(path.join(__dirname, 'patches/manifest.json'), path.join(root, 'patches/manifest.json'));
    fs.copyFileSync(path.join(__dirname, 'apply-security-patches.cjs'), path.join(root, 'apply-security-patches.cjs'));
    for (const patch of manifest) {
      const base = path.join(root, 'node_modules', patch.package);
      fs.mkdirSync(base, { recursive: true });
      fs.writeFileSync(path.join(base, 'package.json'), JSON.stringify({ version: patch.version }));
      for (const file of patch.files) {
        let original = fs.readFileSync(path.join(__dirname, 'node_modules', patch.package, file.path), 'utf8');
        for (const edit of [...file.edits].reverse()) original = original.replace(edit.after, edit.before);
        fs.mkdirSync(path.dirname(path.join(base, file.path)), { recursive: true });
        fs.writeFileSync(path.join(base, file.path), original);
      }
    }
    const run = () => spawnSync(process.execPath, [path.join(root, 'apply-security-patches.cjs')], { encoding: 'utf8' });
    assert.equal(run().status, 0);
    const repeated = run();
    assert.equal(repeated.status, 0);
    assert.match(repeated.stdout, /0 file/);
    const target = path.join(root, 'node_modules/stream-json/filters/FilterBase.js');
    const patched = fs.readFileSync(target, 'utf8');
    fs.appendFileSync(target, '\n// unexpected change');
    assert.notEqual(run().status, 0);
    fs.writeFileSync(target, patched);
    fs.writeFileSync(path.join(root, 'node_modules/stream-json/package.json'), '{"version":"3.5.0"}');
    const changedVersion = run();
    assert.notEqual(changedVersion.status, 0);
    assert.match(changedVersion.stderr, /Review security backport/);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});
