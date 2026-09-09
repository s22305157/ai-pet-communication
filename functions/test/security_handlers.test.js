const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.join(__dirname, '..');
class HttpsError extends Error { constructor(code, message) { super(message); this.code = code; } }
const snapshot = value => ({exists: value !== undefined, data: () => value, get: key => value?.[key]});
function load(file, dependencies, globals = {}) {
  const exports = {};
  vm.runInNewContext(fs.readFileSync(path.join(root, file), 'utf8'), {
    exports, require: name => dependencies[name] || require(path.join(root, name)),
    Date, Buffer, AbortController, setTimeout, clearTimeout, ...globals,
  });
  return exports;
}
function accountHarness({race = false, failStorage = false} = {}) {
  const docs = new Map([['users/a', {uid: 'a'}]]);
  const removed = [];
  const db = {
    collection: name => ({doc: id => ({path: `${name}/${id}`})}),
    recursiveDelete: async ref => { removed.push(ref.path); docs.delete(ref.path); },
    runTransaction: async fn => {
      const attempt = async () => {
        const writes = [];
        const result = await fn({get: async ref => snapshot(docs.get(ref.path)),
          set: (ref, value) => writes.push([ref.path, value])});
        return {writes, result};
      };
      if (race) { await attempt(); docs.set('pets/p', {owner_id: 'b'}); }
      const committed = await attempt();
      committed.writes.forEach(([key, value]) => docs.set(key, value));
      return committed.result;
    },
  };
  const handler = load('account_operations.js', {
    './journal_account_cleanup': {deleteLinkedJournals: async () => {}},
    'firebase-admin/auth': {getAuth: () => ({})},
    'firebase-admin/firestore': {getFirestore: () => db, FieldValue: {serverTimestamp: () => 1}},
    'firebase-admin/storage': {getStorage: () => ({bucket: () => ({name: 'test', file: () => ({delete: async () => {
      if (failStorage) throw Error('temporary');
    }})})})},
    'firebase-functions/v2/https': {onCall: (_, handler) => handler, HttpsError},
  }).deletePetData;
  return {handler, docs, removed};
}
test('delete handler rechecks ownership on transaction retry', async () => {
  const h = accountHarness({race: true});
  await assert.rejects(h.handler({auth: {uid: 'a'}, data: {petId: 'p'}}), error => error.code === 'permission-denied');
  assert.deepEqual(h.removed, []);
  assert.equal(h.docs.get('pets/p').owner_id, 'b');
  assert.equal(h.docs.has('petTombstones/p'), false);
});
test('delete handler rejects deleted accounts and cross-owner tombstones', async () => {
  const h = accountHarness();
  h.docs.set('_deletedUsers/a', {});
  await assert.rejects(h.handler({auth: {uid: 'a'}, data: {petId: 'p'}}), error => error.code === 'permission-denied');
  h.docs.delete('_deletedUsers/a');
  h.docs.set('petTombstones/p', {owner_id: 'b'});
  await assert.rejects(h.handler({auth: {uid: 'a'}, data: {petId: 'p'}}), error => error.code === 'permission-denied');
  assert.deepEqual(h.removed, []);
});
test('delete handler persists avatar for cleanup retries', async () => {
  const h = accountHarness({failStorage: true});
  const avatar = 'https://firebasestorage.googleapis.com/v0/b/test/o/pets%2Fa%2Favatar.png';
  h.docs.set('pets/p', {owner_id: 'a', avatar_url: avatar});
  await assert.rejects(h.handler({auth: {uid: 'a'}, data: {petId: 'p'}}));
  assert.equal(h.docs.get('petTombstones/p').avatar_url, avatar);
  assert.equal(h.docs.has('pets/p'), false);
});
test('account deletion freezes writes before enumeration and tolerates deleted Auth user on retry', async () => {
  let frozen = false;
  const order = [];
  const missingUser = Object.assign(new Error('gone'), {code: 'auth/user-not-found'});
  const db = {
    collection: () => ({
      doc: () => ({set: async () => { frozen = true; order.push('freeze'); }, delete: async () => {}}),
      where: () => ({get: async () => { assert.equal(frozen, true); order.push('list'); return {docs: []}; }}),
    }),
    recursiveDelete: async () => { assert.equal(frozen, true); },
  };
  const handler = load('account_operations.js', {
    './journal_account_cleanup': {deleteLinkedJournals: async () => { assert.equal(frozen, true); }},
    'firebase-admin/auth': {getAuth: () => ({revokeRefreshTokens: async () => { throw missingUser; }, deleteUser: async () => { throw missingUser; }})},
    'firebase-admin/firestore': {getFirestore: () => db, FieldValue: {serverTimestamp: () => 1}},
    'firebase-admin/storage': {getStorage: () => ({bucket: () => ({deleteFiles: async () => { assert.equal(frozen, true); }})})},
    'firebase-functions/v2/https': {onCall: (_, handler) => handler, HttpsError},
  }).deleteOwnAccount;
  const result = await handler({auth: {uid: 'a', token: {auth_time: Math.floor(Date.now()/1000)}}});
  assert.equal(result.deleted, true);
  assert.deepEqual(order, ['freeze', 'list']);
});
function proxyHarness({deleted = false, count = 0, response} = {}) {
  let fetches = 0;
  let revokedCheck;
  const db = {
    collection: name => ({doc: () => ({get: async () => snapshot(
      name === 'users' ? {uid: 'a'} : name === '_deletedUsers' && deleted ? {} : undefined)})}),
    runTransaction: fn => fn({get: async () => snapshot({windowStartMs: Date.now(), count}), set: () => {}}),
  };
  const handler = load('index.js', {
    'firebase-admin/app': {initializeApp: () => {}},
    'firebase-admin/auth': {getAuth: () => ({verifyIdToken: async (_, check) => { revokedCheck = check; return {uid: 'a'}; }})},
    'firebase-admin/firestore': {getFirestore: () => db, Timestamp: {fromMillis: n => n}},
    'firebase-functions/v2/https': {onRequest: (_, handler) => handler},
    'firebase-functions/logger': {error: () => {}},
    './credit_operations': {}, './account_operations': {}, './knowledge_retrieval': {}, './ai_operations': {},
    './proxy_security': {...require('../proxy_security'), assertPublicDns: async () => {}},
  }, {fetch: async () => { fetches++; return response; }}).corsProxy;
  return {async call(url = 'https://lh3.googleusercontent.com/p', bearer = 'Bearer test') {
    const result = {headers: {}, code: 0};
    const res = {setHeader: (key, value) => { result.headers[key] = value; },
      status: code => { result.code = code; return res; }, type: () => res, send: body => { result.body = body; return res; }};
    await handler({method: 'GET', get: () => bearer, query: {url}}, res);
    return {...result, fetches, revokedCheck};
  }};
}

test('credit handlers reject client release and settlement during AI generation', async () => {
  const updates = [];
  const operation = {kind: 'communication', amount: 1, status: 'reserved',
    aiStatus: 'processing', aiStartedAtMs: Date.now()};
  const ref = path => ({path, collection: name => ({doc: id => ref(`${path}/${name}/${id}`)})});
  const db = {collection: name => ({doc: id => ref(`${name}/${id}`)}),
    runTransaction: fn => fn({get: async ref => snapshot(ref.path.includes('creditOperations') ? operation : {points: 2}),
      update: (ref, value) => updates.push({path: ref.path, value})})};
  const handler = load('credit_operations.js', {
    'firebase-admin/firestore': {getFirestore: () => db, Timestamp: {},
      FieldValue: {serverTimestamp: () => 1, delete: () => null}},
    'firebase-functions/v2/https': {onCall: (_, handler) => handler, HttpsError},
    'firebase-functions/v2/scheduler': {onSchedule: () => {}},
  })._handlers.transitionCredit;
  const request = {auth: {uid: 'a'}, data: {requestId: 'request-0000000001'}};
  for (const status of ['released', 'settled']) {
    await assert.rejects(handler(request, status), error => error.code === 'failed-precondition');
  }
  assert.equal(updates.length, 0);
  operation.aiStartedAtMs = Date.now() - 121000;
  await handler(request, 'released');
  assert.equal(updates[0].value.points, 3);
  assert.equal(updates[1].value.status, 'released');
});

test('new reservations and settlements are disabled while pricing is pending', async () => {
  const handlers = load('credit_operations.js', {
    'firebase-admin/firestore': {getFirestore: () => { throw Error('Must not access points'); }},
    'firebase-functions/v2/https': {onCall: (_, handler) => handler, HttpsError},
    'firebase-functions/v2/scheduler': {onSchedule: () => {}},
  })._handlers;
  const request = {auth: {uid: 'a'}, data: {requestId: 'request-0000000001', petId: 'pet1'}};
  await assert.rejects(handlers.reserveCommunicationCreditHandler(request), error => error.code === 'failed-precondition');
  await assert.rejects(handlers.transitionCredit(request, 'settled'), error => error.code === 'failed-precondition');
});
test('proxy handler requires authentication and active account', async () => {
  assert.equal((await proxyHarness().call(undefined, '')).code, 401);
  const result = await proxyHarness({deleted: true}).call();
  assert.equal(result.code, 401);
  assert.equal(result.fetches, 0);
  assert.equal(result.revokedCheck, true);
});
test('proxy handler enforces allowlist and quota before upstream requests', async () => {
  assert.equal((await proxyHarness().call('https://example.test')).code, 400);
  const limited = await proxyHarness({count: 60}).call();
  assert.equal(limited.code, 429);
  assert.equal(limited.fetches, 0);
});
test('proxy handler rejects HTML and serves bounded PNG with security headers', async () => {
  const html = await proxyHarness({response: {ok: true, status: 200, headers: new Map([['content-type', 'text/html']])}}).call();
  assert.equal(html.code, 415);
  const png = Buffer.from([137,80,78,71,13,10,26,10]);
  const result = await proxyHarness({response: {ok: true, status: 200,
    headers: new Map([['content-type', 'image/png'], ['content-length', '8']]),
    body: (async function* () { yield png; })()}}).call();
  assert.equal(result.code, 200);
  assert.equal(result.headers['X-Content-Type-Options'], 'nosniff');
  assert.equal(result.headers['Content-Length'], 8);
});
