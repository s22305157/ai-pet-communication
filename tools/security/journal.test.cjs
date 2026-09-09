const {test, before, beforeEach, after} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {randomUUID} = require('node:crypto');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {getDoc, doc, setDoc} = require('firebase/firestore');
const {getBytes, ref, uploadBytes} = require('firebase/storage');
const functionRequire = require('node:module').createRequire(path.join(__dirname, '../../functions/package.json'));
const {initializeApp, deleteApp} = functionRequire('firebase-admin/app');
const {getFirestore, Timestamp} = functionRequire('firebase-admin/firestore');
const {getStorage} = functionRequire('firebase-admin/storage');
const {createJournalService} = require('../../functions/journal_service');
const {deleteLinkedJournals} = require('../../functions/journal_account_cleanup');
const {LIMITS} = require('../../functions/journal_policy');
const sharp = require('../../functions/node_modules/sharp');
const projectId = 'demo-pawlink-security';
if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_STORAGE_EMULATOR_HOST ||
    !process.env.FIREBASE_AUTH_EMULATOR_HOST) throw Error('Run only through firebase.journal-test.json emulators');
let env, app, db, bucket, service, now;
const request = (data = {}, uid = 'a', token = {}) => ({auth: uid ? {uid, token} : null, data: {operationId: randomUUID(), ...data}});
const call = (name, data = {}, uid = 'a', token = {}) => service.handlers[name](request(data, uid, token));
const denied = (promise, code = 'permission-denied') => assert.rejects(promise, e => e.code === code);
const petRef = (id, uid = 'a') => db.doc(`users/${uid}/journalPets/${id}`);
async function pet(uid = 'a') {
  await call('activatePilot', {consentVersion: 'journal-m1-v1', metricsConsent: true}, uid);
  return (await call('createJournalPet', {name: '小花', species: '兔', focus: '毛孩到家'}, uid)).petId;
}
const entry = (petId, more = {}) => ({petId, entryId: randomUUID(), expectedRevision: 0, occurredAtMs: now - 1000,
  context: '環境適應', observation: '今天主動靠近', action: '', outcome: '', mediaIds: [], ...more});
before(async () => {
  app = initializeApp({projectId, storageBucket: `${projectId}.appspot.com`}, 'journal-test');
  db = getFirestore(app); bucket = getStorage(app).bucket();
  env = await initializeTestEnvironment({projectId,
    firestore: {host: '127.0.0.1', port: 8180, rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8')},
    storage: {host: '127.0.0.1', port: 9299, rules: fs.readFileSync(path.join(__dirname, '../../storage.rules'), 'utf8')}});
});
beforeEach(async () => {
  now = Date.now();
  await env.clearFirestore();
  await bucket.deleteFiles({prefix: 'journal'});
  await db.doc('pilotConfig/features').set({journalEnabled: true, communityEnabled: false, reviewEnabled: false});
  for (const uid of ['a', 'b', 'admin', 'outsider']) {
    await db.doc(`users/${uid}`).set({uid, membershipTier: 'free', displayName: uid});
    if (uid !== 'outsider') await db.doc(`pilotParticipants/${uid}`).set({status: 'invited', expiresAt: Timestamp.fromMillis(now + 86400000)});
  }
  service = createJournalService({db, bucket, now: () => now});
});
after(async () => { await env?.cleanup(); await deleteApp(app); });

test('actual callable emulator rejects anonymous requests and accepts Firebase Auth ID token', async () => {
  const root = `http://127.0.0.1:5101/${projectId}/us-central1/getPilotAccess`;
  const unauth = await fetch(root, {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({data: {}})});
  assert.equal(unauth.status, 401);
  const signup = await fetch('http://127.0.0.1:9198/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator', {
    method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({email: `${randomUUID()}@example.test`, password: 'journal-test-password', returnSecureToken: true})});
  const user = await signup.json();
  assert.ok(user.idToken);
  await db.doc(`users/${user.localId}`).set({uid: user.localId, membershipTier: 'free'});
  const response = await fetch(root, {method: 'POST', headers: {'Content-Type': 'application/json', Authorization: `Bearer ${user.idToken}`}, body: JSON.stringify({data: {}})});
  assert.equal(response.status, 200);
  assert.equal((await response.json()).result.invited, false);
  // Exercise writes over the deployed callable boundary as well as direct handlers.
  await db.doc(`pilotParticipants/${user.localId}`).set({status: 'invited', expiresAt: Timestamp.fromMillis(now + 86400000)});
  async function httpCall(name, data) {
    const response = await fetch(root.replace('getPilotAccess', name), {method: 'POST', headers: {'Content-Type': 'application/json', Authorization: `Bearer ${user.idToken}`},
      body: JSON.stringify({data: {operationId: randomUUID(), ...data}})});
    const result = await response.json();
    assert.equal(response.status, 200, JSON.stringify(result));
    return result.result;
  }
  await httpCall('activatePilot', {consentVersion: 'journal-m1-v1', metricsConsent: true});
  const p = await httpCall('createJournalPet', {name: '小白', species: '兔', focus: '毛孩到家'});
  assert.equal((await httpCall('getJournalHome', {})).pet.species, '兔');
  assert.equal((await petRef(p.petId, user.localId).get()).get('species'), '兔');
  await httpCall('upsertJournalEntry', entry(p.petId));
  const listed = await httpCall('listJournalEntries', {petId: p.petId});
  assert.equal(listed.items.length, 1);
  const bytes = await sharp({create: {width: 40, height: 30, channels: 3, background: 'blue'}}).png().toBuffer();
  const upload = await httpCall('beginJournalUpload', {petId: p.petId, bytes: bytes.length, contentType: 'image/png'});
  await httpCall('uploadJournalBytes', {mediaId: upload.mediaId, base64: bytes.toString('base64')});
  await httpCall('finalizeJournalUpload', {mediaId: upload.mediaId});
  const image = await httpCall('getJournalImage', {mediaId: upload.mediaId});
  assert.equal((await sharp(Buffer.from(image.base64, 'base64')).metadata()).format, 'jpeg');
});

test('flags, invitations, activation and account tombstones fail closed without changing membership', async () => {
  await denied(call('activatePilot', {}, null), 'unauthenticated');
  await denied(call('activatePilot', {consentVersion: 'journal-m1-v1', metricsConsent: true}, 'outsider'));
  await db.doc('pilotConfig/features').delete();
  await denied(call('activatePilot', {consentVersion: 'journal-m1-v1', metricsConsent: true}));
  await db.doc('pilotConfig/features').set({journalEnabled: true});
  await call('activatePilot', {consentVersion: 'journal-m1-v1', metricsConsent: false});
  const initial = (await db.doc('pilotParticipants/a').get()).get('trialEndsAt').toMillis();
  now += 1000;
  await call('activatePilot', {consentVersion: 'journal-m1-v1', metricsConsent: false});
  assert.equal((await db.doc('pilotParticipants/a').get()).get('trialEndsAt').toMillis(), initial);
  assert.equal((await db.doc('users/a').get()).get('membershipTier'), 'free');
  assert.equal((await db.collection('users/a/pilotEvents').get()).size, 0);
  await db.doc('_deletedUsers/a').set({});
  await denied(call('getPilotAccess'));
});

test('one pet per owner, server IDs, verified cloud links and concurrent creates', async () => {
  await call('activatePilot', {consentVersion: 'journal-m1-v1', metricsConsent: true});
  for (const species of [undefined, '', ' '.repeat(3), '兔'.repeat(81)]) {
    await denied(call('createJournalPet', {name: '小白', species, focus: '毛孩到家'}), 'invalid-argument');
  }
  await db.doc('pets/foreign').set({owner_id: 'b'});
  await denied(call('createJournalPet', {name: 'cat', species: '兔', focus: '毛孩到家', linkedPetId: 'foreign'}));
  const attempts = await Promise.allSettled([1, 2].map(() => call('createJournalPet', {name: 'cat', species: '兔', focus: '毛孩到家', petId: 'forged'})));
  assert.equal(attempts.filter(a => a.status === 'fulfilled').length, 1);
  const pets = await db.collection('users/a/journalPets').get();
  assert.equal(pets.size, 1); assert.notEqual(pets.docs[0].id, 'forged');
});

test('free cloud journal cannot access another account or write paid pet data directly', async () => {
  const pid = await pet();
  const e = entry(pid);
  await call('upsertJournalEntry', e);
  await denied(call('listJournalEntries', {petId: pid}, 'b'), 'not-found');
  const a = env.authenticatedContext('a').firestore();
  const b = env.authenticatedContext('b').firestore();
  await assertSucceeds(getDoc(doc(a, `users/a/journalPets/${pid}/entries/${e.entryId}`)));
  await assertFails(getDoc(doc(b, `users/a/journalPets/${pid}/entries/${e.entryId}`)));
  await assertFails(setDoc(doc(a, `users/a/journalPets/${pid}/entries/${e.entryId}`), {observation: 'forged'}));
  await assertFails(setDoc(doc(a, 'pets/forged'), {owner_id: 'a'}));
  await assertFails(setDoc(doc(a, 'pilotParticipants/a'), {status: 'invited'}));
  await assertFails(setDoc(doc(a, 'pilotConfig/features'), {journalEnabled: true}));
});

test('idempotency, stale edits and tombstones prevent lost updates and resurrection', async () => {
  const pid = await pet(); const e = entry(pid); const req = request(e);
  await Promise.all([service.handlers.upsertJournalEntry(req), service.handlers.upsertJournalEntry(req)]);
  assert.equal((await petRef(pid).get()).get('entryCount'), 1);
  await denied(call('upsertJournalEntry', {...e, observation: 'changed'}), 'aborted');
  await denied(service.handlers.upsertJournalEntry({...req, data: {...req.data, observation: 'changed'}}), 'already-exists');
  await call('upsertJournalEntry', {...e, expectedRevision: 1, observation: '更新'});
  await denied(call('deleteJournalEntry', {petId: pid, entryId: e.entryId, expectedRevision: 1}), 'aborted');
  await call('deleteJournalEntry', {petId: pid, entryId: e.entryId, expectedRevision: 2});
  await denied(call('upsertJournalEntry', e), 'aborted');
  assert.equal((await call('listJournalEntries', {petId: pid})).items.length, 0);
});

test('daily and total entry limits use transactional counters', async () => {
  const pid = await pet();
  await petRef(pid).update({entryDay: new Date(now + 8 * 3600000).toISOString().slice(0, 10), dailyEntries: 19});
  const attempts = await Promise.allSettled([call('upsertJournalEntry', entry(pid)), call('upsertJournalEntry', entry(pid))]);
  assert.equal(attempts.filter(x => x.status === 'fulfilled').length, 1);
  await petRef(pid).update({dailyEntries: 0, entryCount: 300});
  await denied(call('upsertJournalEntry', entry(pid)), 'resource-exhausted');
});

test('filters, 20-row cursor pagination, timezone and export remain available when writes stop', async () => {
  const pid = await pet();
  for (let i = 0; i < 25; i++) {
    await petRef(pid).collection('entries').doc(`e${String(i).padStart(2, '0')}`).set({
      observation: `entry${i}`, action: '', outcome: '', context: i % 2 ? '休息' : '環境適應',
      occurredAt: Timestamp.fromMillis(now - i * 1000), createdAt: Timestamp.fromMillis(now), revision: 1, mediaIds: []});
  }
  const page1 = await call('listJournalEntries', {petId: pid});
  const page2 = await call('listJournalEntries', {petId: pid, cursor: page1.cursor});
  assert.equal(page1.items.length, 20); assert.equal(page2.items.length, 5);
  assert.equal(new Set([...page1.items, ...page2.items].map(x => x.id)).size, 25);
  assert.equal((await call('listJournalEntries', {petId: pid, context: '休息'})).items.length, 12);
  assert.equal((await call('listJournalEntries', {petId: pid, fromMs: now - 2500, toMs: now})).items.length, 3);
  await db.doc('pilotConfig/features').update({journalEnabled: false});
  await db.doc('pilotParticipants/a').update({expiresAt: Timestamp.fromMillis(now - 1)});
  await denied(call('upsertJournalEntry', entry(pid)));
  assert.equal((await call('exportJournal', {petId: pid})).entries.length, 25);
  await call('deleteJournalEntry', {petId: pid, entryId: 'e00', expectedRevision: 1});
});

async function photo(pid) {
  const bytes = await sharp({create: {width: 120, height: 80, channels: 3, background: 'green'}}).png().toBuffer();
  const pending = await call('beginJournalUpload', {petId: pid, bytes: bytes.length, contentType: 'image/png'});
  await call('uploadJournalBytes', {mediaId: pending.mediaId, base64: bytes.toString('base64')});
  await call('finalizeJournalUpload', {mediaId: pending.mediaId});
  return pending.mediaId;
}
test('real Storage upload normalizes pixels; public, direct SDK and cross-account reads are denied', async () => {
  const pid = await pet(); const mid = await photo(pid);
  const media = await db.doc(`users/a/journalMedia/${mid}`).get();
  assert.equal(media.get('status'), 'ready');
  assert.equal((await petRef(pid).get()).get('reservedBytes'), 0);
  const image = await call('getJournalImage', {mediaId: mid});
  assert.equal((await sharp(Buffer.from(image.base64, 'base64')).metadata()).format, 'jpeg');
  await denied(call('getJournalImage', {mediaId: mid}, 'b'), 'not-found');
  await assertFails(getBytes(ref(env.unauthenticatedContext().storage(), media.get('path'))));
  await assertFails(getBytes(ref(env.authenticatedContext('a').storage(), media.get('path'))));
  await assertFails(uploadBytes(ref(env.authenticatedContext('a').storage(), `journalUploads/a/${mid}`), Buffer.from('fake')));
  const [metadata] = await bucket.file(media.get('path')).getMetadata();
  assert.equal(metadata.metadata?.firebaseStorageDownloadTokens, undefined);
  const e = entry(pid, {observation: '', mediaIds: [mid]});
  await call('upsertJournalEntry', e);
  await call('deleteJournalEntry', {petId: pid, entryId: e.entryId, expectedRevision: 1});
  await denied(call('getJournalImage', {mediaId: mid}), 'not-found');
  await service.sweep();
  assert.equal((await bucket.file(media.get('path')).exists())[0], false);
  assert.equal((await petRef(pid).get()).get('usedBytes'), 0);
});

test('capacity reservation and cancellation release space once', async () => {
  const pid = await pet();
  await petRef(pid).update({usedBytes: LIMITS.bytes - LIMITS.imageBytes});
  const results = await Promise.allSettled([1, 2].map(() => call('beginJournalUpload', {petId: pid, bytes: 100, contentType: 'image/png'})));
  assert.equal(results.filter(x => x.status === 'fulfilled').length, 1);
  const mid = results.find(x => x.status === 'fulfilled').value.mediaId;
  await call('cancelJournalUpload', {mediaId: mid});
  await call('cancelJournalUpload', {mediaId: mid});
  assert.equal((await petRef(pid).get()).get('reservedBytes'), 0);
  assert.equal((await petRef(pid).get()).get('pendingUploads'), 0);
});

test('expired unattached images cannot be read or attached before the cleanup job runs', async () => {
  const pid = await pet(); const mid = await photo(pid);
  now += 86400001;
  await db.doc('pilotParticipants/a').update({expiresAt: Timestamp.fromMillis(now + 86400000)});
  await denied(call('getJournalImage', {mediaId: mid}), 'not-found');
  await denied(call('upsertJournalEntry', entry(pid, {mediaIds: [mid]})), 'failed-precondition');
  await service.sweep();
  assert.equal((await petRef(pid).get()).get('usedBytes'), 0);
});

test('forged pixels never become ready and expired uploads can be cleaned', async () => {
  const pid = await pet();
  const raw = Buffer.from('not png');
  const m = await call('beginJournalUpload', {petId: pid, bytes: raw.length, contentType: 'image/png'});
  await call('uploadJournalBytes', {mediaId: m.mediaId, base64: raw.toString('base64')});
  await denied(call('finalizeJournalUpload', {mediaId: m.mediaId}), 'invalid-argument');
  assert.equal((await db.doc(`users/a/journalMedia/${m.mediaId}`).get()).get('status'), 'pending');
  now += 86400001;
  await service.sweep();
  assert.equal((await petRef(pid).get()).get('reservedBytes'), 0);
  assert.equal((await bucket.file(`journalUploads/a/${m.mediaId}`).exists())[0], false);
});

test('deletion during normalization cannot commit a ready image or resurrect a pet', async () => {
  const pid = await pet();
  const raw = await sharp({create: {width: 10, height: 10, channels: 3, background: 'red'}}).png().toBuffer();
  const m = await call('beginJournalUpload', {petId: pid, bytes: raw.length, contentType: 'image/png'});
  await call('uploadJournalBytes', {mediaId: m.mediaId, base64: raw.toString('base64')});
  const racing = createJournalService({db, bucket, now: () => now, normalize: async () => {
    await service.markPetDeleted('a', pid); return raw;
  }});
  await denied(racing.handlers.finalizeJournalUpload(request({mediaId: m.mediaId})), 'not-found');
  assert.equal((await db.doc(`users/a/journalMedia/${m.mediaId}`).get()).get('status'), 'pending');
  await service.sweep();
  assert.equal((await petRef(pid).get()).exists, false);
  assert.equal((await bucket.getFiles({prefix: 'journalImages/a/'}))[0].length, 0);
});

test('linked pet and account cleanup remove journals and media, preserving unrelated data', async () => {
  const pid = await pet(); const other = await pet('b');
  const mid = await photo(pid);
  await petRef(pid).update({linkedPetId: 'original'});
  await db.doc('petTombstones/original').set({owner_id: 'a'});
  await denied(call('getJournalHome'), 'not-found');
  await deleteLinkedJournals(db, bucket, 'a', 'original');
  assert.equal((await petRef(pid).get()).exists, false);
  assert.equal((await db.doc(`users/a/journalMedia/${mid}`).get()).exists, false);
  assert.equal((await petRef(other, 'b').get()).exists, true);
  await deleteLinkedJournals(db, bucket, 'b');
  assert.equal((await db.doc('pilotParticipants/b').get()).exists, false);
});

test('admin capability is a custom claim; invitation updates never rewrite trial or membership', async () => {
  const pid = await pet(); assert.ok(pid);
  const before = (await db.doc('pilotParticipants/a').get()).get('trialEndsAt').toMillis();
  const data = {uid: 'a', status: 'disabled', expiresAtMs: now + 30000, isTest: true};
  await denied(call('adminSetPilotParticipant', data, 'b'));
  await call('adminSetPilotParticipant', data, 'admin', {pilotAdmin: true});
  assert.equal((await db.doc('pilotParticipants/a').get()).get('trialEndsAt').toMillis(), before);
  assert.equal((await db.doc('users/a').get()).get('membershipTier'), 'free');
  await denied(call('upsertJournalEntry', entry(pid)));
  assert.ok((await call('exportJournal', {petId: pid})).entries);
});
