const test = require('node:test');
const assert = require('node:assert/strict');
// This emulates provider verification only. It does not prove production attestation.
process.env.ENFORCE_APP_CHECK = 'true';
process.env.FIREBASE_DEBUG_MODE = 'true';
process.env.FIREBASE_DEBUG_FEATURES = JSON.stringify({skipTokenVerification: true});
const express = require('express');
const {onCall} = require('firebase-functions/v2/https');
const {enforceAppCheck} = require('../callable_policy');
test('configured App Check enforcement rejects missing tokens before work', async () => {
  let work = 0;
  const app = express();
  app.use(express.json());
  app.post('/', onCall({enforceAppCheck}, () => { work++; return {ok:true}; }));
  const server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
  try {
    const url = `http://127.0.0.1:${server.address().port}/`;
    const request = token => fetch(url, {method:'POST', headers:{'Content-Type':'application/json', ...(token ? {'X-Firebase-AppCheck':token} : {})}, body:'{"data":{}}'});
    assert.equal((await request()).status, 401);
    assert.equal(work, 0);
    const token = [Buffer.from('{"alg":"none"}').toString('base64url'), Buffer.from('{"sub":"emulator-test-app"}').toString('base64url'), ''].join('.');
    const response = await request(token);
    assert.equal(response.status, 200);
    assert.equal(work, 1);
  } finally { await new Promise(resolve => server.close(resolve)); }
});
