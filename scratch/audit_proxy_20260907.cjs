// Offline handler checks. No real fetches, credentials, or cloud writes.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const context = {
  exports: {}, Buffer,
  require: (name) => name === 'firebase-functions/v2/https'
    ? { onRequest: (_options, handler) => handler }
    : { error: () => {} },
};
vm.runInNewContext(fs.readFileSync('functions/index.js', 'utf8'), context);
async function check(url, type) {
  let fetched;
  context.fetch = async (target) => {
    fetched = target;
    return { ok: true, headers: { get: () => type },
      arrayBuffer: async () => Buffer.from('<html>offline fixture</html>') };
  };
  const headers = {};
  const res = { statusCode: 200, status(n) { this.statusCode = n; return this; },
    setHeader(k, v) { headers[k] = v; }, send(body) { this.body = body; } };
  await context.exports.corsProxy({ query: { url } }, res);
  assert.equal(fetched, url);
  assert.equal(res.statusCode, 200);
  assert.equal(headers['Content-Type'], type);
}
(async () => {
  await check('http://127.0.0.1/private', 'text/plain');
  console.log('REPRO: unauthenticated loopback URL accepted (mock fetch only)');
  await check('https://example.invalid/page', 'text/html');
  console.log('REPRO: arbitrary HTML returned as text/html without sandbox CSP');
})().catch((e) => { console.error(e); process.exitCode = 1; });
