const {test, before, beforeEach, after} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const {initializeTestEnvironment, assertFails} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc} = require('firebase/firestore');
const backend = require('node:module').createRequire(path.join(__dirname, '../../functions/package.json'));
const {initializeApp, deleteApp} = backend('firebase-admin/app');
const {getFirestore, Timestamp} = backend('firebase-admin/firestore');
const {getStorage} = backend('firebase-admin/storage');
const {Storage} = backend('@google-cloud/storage');
const sharp = backend('sharp');
const {loadPhotos} = require('../../functions/communication_photos');
const {sweepCommunicationPhotos, runCommunicationPhotoCleanup} = require('../../functions/communication_photo_cleanup');
const {PHOTO_TTL_MS, PROCESSING_GRACE_MS} = require('../../functions/communication_photo_policy');
const projectId = 'demo-pawlink-security';
for (const name of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_STORAGE_EMULATOR_HOST']) {
  if (!/^127\.0\.0\.1:\d+$/.test(process.env[name] || '')) throw Error('Requires loopback demo emulators');
}
let app, db, bucket, env, png;
const photoPath = id => `communicationPhotos/a/${id}/0`;
before(async () => {
  app = initializeApp({projectId, storageBucket: `${projectId}.appspot.com`}, 'communication-photo-test');
  db = getFirestore(app);
  bucket = getStorage(app).bucket();
  env = await initializeTestEnvironment({projectId, firestore: {host: '127.0.0.1', port: 8180,
    rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8')}});
  png = await sharp({create: {width: 4, height: 3, channels: 3, background: 'blue'}}).png().toBuffer();
});
beforeEach(async () => {
  await env.clearFirestore();
  await bucket.deleteFiles({prefix: 'communicationPhotos/'});
});
after(async () => {
  await bucket?.deleteFiles({prefix: 'communicationPhotos/'});
  await env?.cleanup();
  if (app) await deleteApp(app);
});
async function upload(id, bytes = png) {
  const file = bucket.file(photoPath(id));
  await file.save(bytes, {resumable: false, metadata: {contentType: 'image/png'}});
  const [metadata] = await file.getMetadata();
  return {file, metadata};
}

test('Storage metadata supports image normalization and the exact 24-hour expiry boundary', async () => {
  const id = 'photo-request-0001';
  const {metadata} = await upload(id);
  const expires = Date.parse(metadata.timeCreated) + PHOTO_TTL_MS;
  const input = {media: {photos: [photoPath(id)]}, uid: 'a', requestId: id, bucket};
  const photos = await loadPhotos({...input, now: () => expires - 1});
  const info = await sharp(Buffer.from(photos[0].split(',')[1], 'base64')).metadata();
  assert.equal(info.format, 'jpeg');
  assert.equal(info.width, 4);
  await assert.rejects(loadPhotos({...input, now: () => expires}), {code: 'failed-precondition'});
});

test('sweeper preserves fresh and active photos and deletes expired or abandoned generations', async () => {
  const ids = ['orphan', 'completed', 'failed', 'active', 'unknown-start', 'abandoned'];
  const uploaded = await Promise.all(ids.map(id => upload(id)));
  assert.equal((await sweepCommunicationPhotos({db, bucket})).deleted, 0);
  const at = Math.max(...uploaded.map(({metadata}) => Date.parse(metadata.timeCreated))) + PHOTO_TTL_MS + 100;
  for (const [id, value] of Object.entries({
    completed: {status: 'completed'}, failed: {status: 'failed'},
    active: {status: 'processing', createdAt: Timestamp.fromMillis(at - 1000)},
    'unknown-start': {status: 'processing'},
    abandoned: {status: 'processing', createdAt: Timestamp.fromMillis(at - PROCESSING_GRACE_MS)},
  })) await db.doc(`users/a/aiRequests/${id}`).set(value);
  const result = await runCommunicationPhotoCleanup({db, bucket, now: () => at});
  assert.equal(result.deleted, 4);
  const [remaining] = await bucket.getFiles({prefix: 'communicationPhotos/'});
  assert.deepEqual(remaining.map(file => file.name).sort(), ['active', 'unknown-start'].map(photoPath));
  assert.equal((await db.doc('_maintenance/communicationPhotoCleanup').get()).get('pageToken'), null);
});

test('Storage SDK sends generation conditions and cleanup handles HTTP 412', async t => {
  const {metadata} = await upload('conditional-delete');
  const requests = [];
  const server = http.createServer((request, response) => {
    requests.push({method: request.method, url: new URL(request.url, 'http://localhost')});
    response.writeHead(412, {'Content-Type': 'application/json'});
    response.end(JSON.stringify({error: {code: 412, message: 'Generation changed'}}));
  });
  t.after(() => new Promise(resolve => server.close(resolve)));
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const endpoint = `http://127.0.0.1:${server.address().port}`;
  const previousHost = process.env.STORAGE_EMULATOR_HOST;
  let storage;
  // This SDK reads its base URL synchronously from the environment, even when
  // apiEndpoint is supplied. Restore it before any asynchronous operation.
  try {
    process.env.STORAGE_EMULATOR_HOST = `${endpoint}/storage/v1`;
    storage = new Storage({projectId, apiEndpoint: endpoint,
      useAuthWithCustomEndpoint: false, retryOptions: {autoRetry: false}});
  } finally {
    if (previousHost === undefined) delete process.env.STORAGE_EMULATOR_HOST;
    else process.env.STORAGE_EMULATOR_HOST = previousHost;
  }
  const conditionalBucket = storage.bucket(bucket.name);
  const result = await sweepCommunicationPhotos({db, now: () => Date.parse(metadata.timeCreated) + PHOTO_TTL_MS,
    bucket: {getFiles: options => bucket.getFiles(options), file: (...args) => conditionalBucket.file(...args)}});
  assert.deepEqual(result, {deleted: 0, skipped: 1, pageToken: null});
  assert.equal(requests.length, 1);
  assert.equal(requests[0].method, 'DELETE');
  assert.equal(decodeURIComponent(requests[0].url.pathname),
    `/storage/v1/b/${bucket.name}/o/${photoPath('conditional-delete')}`);
  assert.equal(requests[0].url.searchParams.get('generation'), metadata.generation);
  assert.equal(requests[0].url.searchParams.get('ifGenerationMatch'), metadata.generation);
});

test('replacing an object after listing cannot cause cleanup to delete the new generation', async t => {
  // Probe the emulator independently of our cleanup/SDK. Firebase Tools 15.29.0
  // ignores these query parameters. Keep the real race assertion for versions
  // that support them, and report an explicit skip until that capability exists.
  const probe = await upload('precondition-probe');
  const probeUrl = new URL(`http://${process.env.FIREBASE_STORAGE_EMULATOR_HOST}` +
    `/storage/v1/b/${bucket.name}/o/${encodeURIComponent(probe.file.name)}`);
  probeUrl.searchParams.set('generation', probe.metadata.generation);
  probeUrl.searchParams.set('ifGenerationMatch', (BigInt(probe.metadata.generation) + 1n).toString());
  const response = await fetch(probeUrl, {method: 'DELETE', headers: {Authorization: 'Bearer owner'}});
  await response.arrayBuffer();
  if (response.ok) {
    t.skip('Storage emulator ignores generation preconditions; real replacement protection needs a GCS integration environment');
    return;
  }
  assert.equal(response.status, 412, 'Generation mismatch must fail with HTTP 412');
  await probe.file.delete();
  const id = 'replacement';
  const {metadata} = await upload(id);
  const at = Date.parse(metadata.timeCreated) + PHOTO_TTL_MS + 1;
  let replaced = false;
  const observedBucket = {
    getFiles: async options => {
      const listed = await bucket.getFiles(options);
      if (!replaced) {
        replaced = true;
        const newer = await upload(id, Buffer.from('replacement fixture'));
        assert.notEqual(newer.metadata.generation, metadata.generation);
      }
      return listed;
    },
    file: (...args) => bucket.file(...args),
  };
  await sweepCommunicationPhotos({db, bucket: observedBucket, now: () => at});
  const [bytes] = await bucket.file(photoPath(id)).download();
  assert.equal(bytes.toString(), 'replacement fixture');
});

test('cleanup checkpoint is not readable or writable by clients, including admins', async () => {
  await db.doc('_maintenance/communicationPhotoCleanup').set({pageToken: 'local-test-cursor'});
  for (const context of [env.unauthenticatedContext(), env.authenticatedContext('a'),
    env.authenticatedContext('admin', {pilotAdmin: true})]) {
    const target = doc(context.firestore(), '_maintenance/communicationPhotoCleanup');
    await assertFails(getDoc(target));
    await assertFails(setDoc(target, {pageToken: null}));
  }
});
