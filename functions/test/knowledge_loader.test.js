const test = require('node:test');
const assert = require('node:assert/strict');
const {createHash} = require('node:crypto');
const {createIndexLoader} = require('../knowledge_retrieval');
const hash = value => createHash('sha256').update(value).digest('hex');

test('bundled knowledge verifies its manifest and never fetches Hosting', async () => {
  const bytes = Buffer.from('encrypted-fixture');
  let decryptions = 0;
  const load = createIndexLoader({env: {}, fetcher: () => assert.fail('Unexpected network'),
    read: async name => name.endsWith('manifest.json') ? JSON.stringify({sha256: hash(bytes)}) : bytes,
    decrypt: value => { decryptions++; return {value}; }});
  const [first, second] = await Promise.all([load(), load()]);
  assert.equal(first, second);
  assert.equal(decryptions, 1);
});

test('remote knowledge requires a pinned hash, checks integrity and retries failures', async () => {
  const env = {KB_INDEX_URL: 'https://example.test/v1.enc'};
  let calls = 0, corrupt = true;
  const load = createIndexLoader({env,
    fetcher: async () => { calls++; return {ok: true, arrayBuffer: async () => Buffer.from(corrupt ? 'wrong' : 'v1')}; },
    decrypt: value => value});
  await assert.rejects(load(), /SHA-256/);
  assert.equal(calls, 0);
  env.KB_INDEX_SHA256 = hash('v1');
  await assert.rejects(load(), /integrity/);
  corrupt = false;
  assert.equal(await load(), 'v1');
  assert.equal(await load(), 'v1');
  assert.equal(calls, 2);
});

test('version changes invalidate cached knowledge and do not reuse another deployment source', async () => {
  const env = {KB_INDEX_URL: 'https://example.test/v1', KB_INDEX_SHA256: hash('v1')};
  const urls = [];
  const load = createIndexLoader({env, fetcher: async url => {
    urls.push(url); return {ok: true, arrayBuffer: async () => Buffer.from(url.endsWith('v1') ? 'v1' : 'v2')};
  }, decrypt: value => value});
  assert.equal(await load(), 'v1');
  env.KB_INDEX_URL = 'https://staging.example.test/v2';
  env.KB_INDEX_SHA256 = hash('v2');
  assert.equal(await load(), 'v2');
  assert.equal(urls.length, 2);
  env.KB_INDEX_URL = 'http://example.test/v2';
  await assert.rejects(load(), /HTTPS/);
});
