const {test, before, beforeEach, after} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {randomUUID} = require('node:crypto');
const {initializeTestEnvironment, assertFails} = require('@firebase/rules-unit-testing');
const {getDoc, doc, setDoc} = require('firebase/firestore');
const backend = require('node:module').createRequire(path.join(__dirname, '../../functions/package.json'));
const {initializeApp, deleteApp} = backend('firebase-admin/app');
const {getFirestore, Timestamp} = backend('firebase-admin/firestore');
const {getStorage} = backend('firebase-admin/storage');
const {getAuth} = backend('firebase-admin/auth');
const {createJournalService} = require('../../functions/journal_service');
const {DAY} = require('../../functions/pilot_metrics');
const projectId = 'demo-pawlink-security';
if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_STORAGE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) throw Error('Requires demo Firebase emulators');
let env, app, db, bucket, service, now;
const stamp = ms => Timestamp.fromMillis(ms);
const request = (data = {}, uid = 'a', token = {}) => ({auth: uid ? {uid, token} : null, data: {operationId: randomUUID(), ...data}});
const call = (name, data = {}, uid = 'a', token = {}) => service.handlers[name](request(data, uid, token));
const adminCall = (name, data = {}) => call(name, data, 'admin', {pilotAdmin: true});
const deny = (promise, code = 'permission-denied') => assert.rejects(promise, e => e.code === code);
before(async () => {
  app = initializeApp({projectId, storageBucket: `${projectId}.appspot.com`}, 'm4-test'); db = getFirestore(app); bucket = getStorage(app).bucket();
  env = await initializeTestEnvironment({projectId, firestore: {host: '127.0.0.1', port: 8180,
    rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8')}});
});
beforeEach(async () => {
  now = Date.parse('2026-09-14T08:30:00+08:00'); await env.clearFirestore();
  await db.doc('pilotConfig/features').set({journalEnabled: true, reviewEnabled: true, communityEnabled: true, communityWriteEnabled: true});
  for (const uid of ['a', 'b', 'admin', 'test', 'outsider']) {
    await db.doc(`users/${uid}`).set({uid, membershipTier: 'free', points: 7, displayName: 'PRIVATE NAME'});
    if (uid !== 'outsider') await db.doc(`pilotParticipants/${uid}`).set({status: 'invited', expiresAt: stamp(now + 90 * DAY),
      activatedAt: stamp(now), trialEndsAt: stamp(now + 28 * DAY), metricsConsent: true, isTest: uid === 'test',
      reviewAnalysisEnabled: true, reviewConsentVersion: 'weekly-review-v1'});
  }
  // Emulates the actual Auth claim lookup; participant.admin is intentionally absent.
  service = createJournalService({db, bucket, now: () => now, metricAdminIds: async () => ['admin'], reviewProvider: async ({input}) => ({result: {
    happenings: [{text: '這週留下日常', entryIds: [input.entries[0].entryId]}],
    observations: [{text: '可能仍需繼續觀察', entryIds: [input.entries[0].entryId]}], tips: [], petVoice: ''}, usage: {inputTokens: 100, outputTokens: 50}})});
});
after(async () => { await env?.cleanup(); await deleteApp(app); });
const participant = uid => db.doc(`pilotParticipants/${uid}`);
const interest = interested => ({interested, priceVersion: 'pilot-twd199-v1'});
async function pet(uid = 'a') { return (await call('createJournalPet', {name: 'PRIVATE PET', species: '兔', focus: '毛孩到家'}, uid)).petId; }
async function entry(petId, offset = 0) {
  const d = {petId, entryId: randomUUID(), expectedRevision: 0, occurredAtMs: now - offset * DAY,
    context: '休息', observation: 'PRIVATE JOURNAL 在窗邊休息', action: '', outcome: '', mediaIds: []};
  await call('upsertJournalEntry', d); return d;
}
test('M4 preferences persist across requests, enforce identity and never change membership or trial', async () => {
  const before = (await participant('a').get()).get('trialEndsAt');
  await deny(call('getPilotInterest', {}, null), 'unauthenticated');
  await deny(call('getPilotInterest', {}, 'outsider'));
  await call('setPilotInterest', {...interest(true), uid: 'b'});
  assert.equal((await call('getPilotInterest')).interested, true);
  assert.equal((await call('getPilotInterest', {}, 'b')).interested, false);
  assert.equal((await db.doc('users/a').get()).get('membershipTier'), 'free');
  assert.equal((await db.doc('users/a').get()).get('points'), 7);
  assert.deepEqual((await participant('a').get()).get('trialEndsAt'), before);
  await deny(call('setPilotInterest', {interested: 'yes', priceVersion: 'pilot-twd199-v1'}), 'invalid-argument');
});
test('M4 retries and multiple devices do not inflate price viewers; cancellation works after eligibility expires', async () => {
  const r = request(interest(true));
  await Promise.all([service.handlers.setPilotInterest(r), service.handlers.setPilotInterest(r)]);
  await call('markPilotPriceViewed'); await call('markPilotPriceViewed');
  assert.equal((await db.collection('users/a/pilotEvents').get()).size, 1);
  let report = await adminCall('adminGetPilotMetrics'); assert.equal(report.metrics.upgradeInterest.rate, 1);
  await participant('a').update({expiresAt: stamp(now)});
  await deny(call('setPilotInterest', interest(true)));
  await call('setPilotInterest', interest(false));
  report = await adminCall('adminGetPilotMetrics'); assert.equal(report.metrics.upgradeInterest.rate, 0);
  await deny(service.handlers.setPilotInterest({...r, data: {...r.data, interested: false}}), 'already-exists');
});
test('M4 notification interest works without measurement or feature flags', async () => {
  await participant('a').update({metricsConsent: false});
  await db.doc('pilotConfig/features').set({});
  await call('setPilotInterest', interest(true)); await call('markPilotPriceViewed');
  assert.equal((await call('getPilotInterest')).interested, true);
  assert.equal((await db.collection('users/a/pilotEvents').get()).size, 0);
});
test('M4 consent withdrawal excludes data immediately, cleans in batches, and cannot be bypassed by activation', async () => {
  const batch = db.batch();
  for (let i = 0; i < 401; i++) batch.set(db.doc(`users/a/pilotEvents/e${i}`), {type: 'price_viewed', createdAt: stamp(now), expiresAt: stamp(now + 90 * DAY)});
  await batch.commit(); await call('setPilotMetricsConsent', {enabled: false});
  assert.equal((await adminCall('adminGetPilotMetrics')).metrics.upgradeInterest.denominator, 0);
  await deny(call('activatePilot', {consentVersion: 'journal-m1-v1', metricsConsent: true}), 'failed-precondition');
  await deny(call('setPilotMetricsConsent', {enabled: true}), 'failed-precondition');
  await service.sweep(); assert.equal((await db.collection('users/a/pilotEvents').get()).size, 1);
  await service.sweep(); assert.equal((await db.collection('users/a/pilotEvents').get()).size, 0);
  now += DAY; await call('setPilotMetricsConsent', {enabled: true});
  assert.equal((await adminCall('adminGetPilotMetrics')).metrics.incompleteCohorts, 1);
});
test('M4 legacy activation consent withdrawal follows the same cleanup path', async () => {
  await call('markPilotPriceViewed');
  await call('activatePilot', {consentVersion: 'journal-m1-v1', metricsConsent: false});
  assert.equal((await participant('a').get()).get('metricsCleanupPending'), true);
  await service.sweep(); assert.equal((await db.collection('users/a/pilotEvents').get()).size, 0);
});
test('M4 actual journal and community writes produce linked metadata and correct mature ratios', async () => {
  const pid = await pet(), e = await entry(pid);
  const post = await call('publishCommunityPost', {petId: pid, entryId: e.entryId, expectedRevision: 1,
    alias: 'PUBLIC ALIAS', text: 'PUBLIC POST', topic: '毛孩到家', mediaIds: [], confirmed: true});
  await call('addCommunityComment', {postId: post.postId, text: 'PUBLIC COMMENT', alias: '同伴'}, 'b');
  now += 8 * DAY;
  const r = await adminCall('adminGetPilotMetrics');
  assert.equal(r.metrics.communityResponses.rate, 1); assert.equal(r.metrics.activation.numerator, 1);
  const rows = await db.collection('users/a/pilotEvents').get();
  const json = JSON.stringify(rows.docs.map(d => d.data()));
  for (const word of ['PRIVATE', 'PUBLIC', post.postId, pid]) assert.ok(!json.includes(word));
  assert.ok(rows.docs.some(d => /^[a-f0-9]{64}$/.test(d.get('subject'))));
});
test('M4 deleted accounts and Auth admins are excluded even before physical cleanup', async () => {
  await call('markPilotPriceViewed', {}, 'b');
  await db.doc('_deletedUsers/b').set({deletedAt: stamp(now)});
  const r = await adminCall('adminGetPilotMetrics');
  assert.equal(r.metrics.measuredParticipants, 1); assert.equal(r.metrics.upgradeInterest.denominator, 0);
});
test('M4 regenerated reviews retain separate generations and views link only to the displayed generation', async () => {
  const pid = await pet(), first = await entry(pid, 7); await entry(pid, 6); await entry(pid, 5);
  const data = {petId: pid, week: '2026-09-07'};
  assert.equal((await call('requestWeeklyReview', data)).status, 'ready');
  await call('markWeeklyReviewViewed', data);
  await call('upsertJournalEntry', {...first, expectedRevision: 1, observation: 'PRIVATE JOURNAL 新的觀察'});
  assert.equal((await call('requestWeeklyReview', data)).status, 'ready');
  now += 8 * DAY;
  const report = await adminCall('adminGetPilotMetrics');
  assert.equal(report.metrics.reviewViews.denominator, 2); assert.equal(report.metrics.reviewViews.numerator, 1);
});
test('M4 cost records are admin only, validate values, deduplicate retries and detect concurrent updates', async () => {
  const data = {day: '2026-09-14', expectedRevision: 0, modelTwd: 12.5, storageTwd: 2.25, requests: 52, minutes: 15};
  await deny(call('adminSetPilotCost', data)); await deny(call('adminGetPilotMetrics'));
  await deny(call('adminGetPilotCost', {day: data.day}));
  await deny(adminCall('adminSetPilotCost', {...data, day: '2026-02-30'}), 'invalid-argument');
  await deny(adminCall('adminSetPilotCost', {...data, minutes: 1.5}), 'invalid-argument');
  const req = request(data, 'admin', {pilotAdmin: true});
  await Promise.all([service.handlers.adminSetPilotCost(req), service.handlers.adminSetPilotCost(req)]);
  await deny(adminCall('adminSetPilotCost', {...data, modelTwd: 99}), 'aborted');
  await adminCall('adminSetPilotCost', {...data, expectedRevision: 1, modelTwd: 20});
  const r = await adminCall('adminGetPilotMetrics'); assert.equal(r.costs.modelTwd, 20); assert.equal(r.costs.recordedDays, 1);
  assert.equal((await adminCall('adminGetPilotCost', {day: data.day})).revision, 2);
});
test('M4 event expiry and retained snapshots contain only aggregate values', async () => {
  await call('markPilotPriceViewed');
  await db.doc('users/a/pilotEvents/expired').set({type: 'price_viewed', createdAt: stamp(now - 90 * DAY), expiresAt: stamp(now)});
  await service.sweep(); assert.equal((await db.doc('users/a/pilotEvents/expired').get()).exists, false);
  const snapshots = await db.collection('_pilotMetricSnapshots').get(); assert.equal(snapshots.size, 1);
  const result = JSON.stringify(snapshots.docs[0].data());
  for (const s of ['PRIVATE', 'users/', 'subject', 'interested', 'actor']) assert.ok(!result.includes(s));
  assert.equal(snapshots.docs[0].get('metrics.upgradeInterest.denominator'), 1);
});
test('M4 report refuses to calculate ratios from a truncated participant set', async () => {
  const batch = db.batch();
  for (let i = 0; i < 498; i++) batch.set(participant(`extra${i}`), {metricsConsent: true, activatedAt: stamp(now)});
  await batch.commit();
  const r = await adminCall('adminGetPilotMetrics'); assert.equal(r.truncated, true); assert.equal(r.metrics, null);
  await service.sweep(); assert.equal((await db.collection('_pilotMetricSnapshots').get()).size, 0);
});
test('M4 Firestore Rules deny direct preferences, events, costs and snapshots even to admins', async () => {
  for (const uid of ['a', 'b', 'admin']) {
    const client = env.authenticatedContext(uid, {pilotAdmin: uid === 'admin'}).firestore();
    for (const key of ['pilotParticipants/a', 'users/a/pilotEvents/forged', '_pilotCosts/2026-09-14', '_pilotMetricSnapshots/2026-09-14']) {
      await assertFails(getDoc(doc(client, key))); await assertFails(setDoc(doc(client, key), {metricsConsent: true}));
    }
  }
});
test('M4 actual HTTP callable transport checks Auth and saves server-owned preferences', async () => {
  const response = await fetch('http://127.0.0.1:9198/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator',
    {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({email: `${randomUUID()}@example.test`, password: 'emulator-test-only', returnSecureToken: true})});
  const u = await response.json(); assert.ok(u.idToken);
  await db.doc(`users/${u.localId}`).set({uid: u.localId});
  await participant(u.localId).set({status: 'invited', activatedAt: stamp(Date.now()), expiresAt: stamp(Date.now() + DAY)});
  const http = async (name, data, token = u.idToken) => fetch(`http://127.0.0.1:5101/${projectId}/us-central1/${name}`,
    {method: 'POST', headers: {'Content-Type': 'application/json', ...(token ? {Authorization: `Bearer ${token}`} : {})}, body: JSON.stringify({data: {operationId: randomUUID(), ...data}})});
  assert.equal((await http('getPilotInterest', {}, null)).status, 401);
  assert.equal((await http('setPilotInterest', interest(true))).status, 200);
  assert.equal((await (await http('getPilotInterest', {})).json()).result.interested, true);
  assert.equal((await http('adminGetPilotMetrics', {})).status, 403);
  assert.equal((await http('adminGetPilotCost', {day: '2026-09-14'})).status, 403);
  assert.equal((await http('adminSetPilotCost', {pilotAdmin: true, day: '2026-09-14', modelTwd: 0, storageTwd: 0, requests: 0, minutes: 0, expectedRevision: 0})).status, 403);
  await getAuth(app).setCustomUserClaims(u.localId, {pilotAdmin: true});
  const signedIn = await fetch('http://127.0.0.1:9198/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=emulator',
    {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({email: u.email, password: 'emulator-test-only', returnSecureToken: true})});
  const adminToken = (await signedIn.json()).idToken; assert.ok(adminToken);
  const dashboard = await http('adminGetPilotMetrics', {}, adminToken); assert.equal(dashboard.status, 200);
  assert.equal((await dashboard.json()).result.truncated, false);
});
