const {test, before, beforeEach, after} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {randomUUID} = require('node:crypto');
const {initializeTestEnvironment, assertFails} = require('@firebase/rules-unit-testing');
const {getDoc, doc, setDoc} = require('firebase/firestore');
const {getBytes, ref, uploadBytes} = require('firebase/storage');
const backend = require('node:module').createRequire(path.join(__dirname, '../../functions/package.json'));
const {initializeApp, deleteApp} = backend('firebase-admin/app');
const {getFirestore, Timestamp} = backend('firebase-admin/firestore');
const {getStorage} = backend('firebase-admin/storage');
const {createJournalService} = require('../../functions/journal_service');
const {deleteLinkedJournals} = require('../../functions/journal_account_cleanup');
const sharp = backend('sharp');
const projectId = 'demo-pawlink-security';
if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_STORAGE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) throw Error('Requires demo Firebase emulators');
let env, app, db, bucket, service, now, calls, provider;
const request = (data = {}, uid = 'a', token = {}) => ({auth: uid ? {uid, token} : null, data: {operationId: randomUUID(), ...data}});
const call = (name, data = {}, uid = 'a', token = {}) => service.handlers[name](request(data, uid, token));
const deny = (promise, code = 'permission-denied') => assert.rejects(promise, e => e.code === code);
const petRef = (pid, uid = 'a') => db.doc(`users/${uid}/journalPets/${pid}`);
const stamp = ms => Timestamp.fromMillis(ms);
const output = input => ({result: {happenings: [{text: '主人記錄了相處日常', entryIds: [input.entries[0].entryId]}],
  observations: [{text: '可能仍需觀察，尚無法判斷趨勢', entryIds: [input.entries[0].entryId]}], tips: [{text: '繼續留下相處情境', entryIds: [input.entries[0].entryId]}], petVoice: '陪你待一下。'}, usage: {inputTokens: 100, outputTokens: 80}});
before(async () => {
  app = initializeApp({projectId, storageBucket: `${projectId}.appspot.com`}, 'm23-test'); db = getFirestore(app); bucket = getStorage(app).bucket();
  env = await initializeTestEnvironment({projectId,
    firestore: {host: '127.0.0.1', port: 8180, rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8')},
    storage: {host: '127.0.0.1', port: 9299, rules: fs.readFileSync(path.join(__dirname, '../../storage.rules'), 'utf8')}});
});
beforeEach(async () => {
  now = Date.parse('2026-09-14T08:30:00+08:00'); calls = 0;
  await env.clearFirestore(); await bucket.deleteFiles({prefix: 'journal'}); await bucket.deleteFiles({prefix: 'communityImages/'});
  await db.doc('pilotConfig/features').set({journalEnabled: true, reviewEnabled: true, communityEnabled: true, communityWriteEnabled: true});
  for (const uid of ['a', 'b', 'c', 'admin', 'outsider']) {
    await db.doc(`users/${uid}`).set({uid, membershipTier: 'free', points: 7, displayName: 'PRIVATE NAME'});
    if (uid !== 'outsider') await db.doc(`pilotParticipants/${uid}`).set({status: 'invited', expiresAt: stamp(now + 90 * 86400000), activatedAt: stamp(now - 1000), trialEndsAt: stamp(now + 28 * 86400000), reviewAnalysisEnabled: true, reviewConsentVersion: 'weekly-review-v1'});
  }
  provider = async ({input}) => output(input);
  service = createJournalService({db, bucket, now: () => now, reviewProvider: async args => { calls++; return provider(args); }});
});
after(async () => { await env?.cleanup(); await deleteApp(app); });
async function pet(uid = 'a') { return (await call('createJournalPet', {name: 'PRIVATE PET', species: '兔', focus: '毛孩到家'}, uid)).petId; }
async function entry(pid, more = {}, uid = 'a') {
  const value = {petId: pid, entryId: randomUUID(), expectedRevision: 0, occurredAtMs: now - 7 * 86400000,
    context: '休息', observation: '今天在窗邊休息', action: '靜靜陪伴', outcome: '', mediaIds: [], ...more};
  await call('upsertJournalEntry', value, uid); return value;
}
async function week(uid = 'a') {
  const pid = await pet(uid), rows = [];
  for (let i = 0; i < 3; i++) rows.push(await entry(pid, {occurredAtMs: now - (7 - i) * 86400000}, uid));
  return {pid, rows};
}
async function photo(pid, uid = 'a') {
  const bytes = await sharp({create: {width: 40, height: 30, channels: 3, background: 'green'}}).png().toBuffer();
  const pending = await call('beginJournalUpload', {petId: pid, bytes: bytes.length, contentType: 'image/png'}, uid);
  await call('uploadJournalBytes', {mediaId: pending.mediaId, base64: bytes.toString('base64')}, uid);
  await call('finalizeJournalUpload', {mediaId: pending.mediaId}, uid); return pending.mediaId;
}
const shareData = e => ({petId: e.petId, entryId: e.entryId, expectedRevision: 1, alias: '同伴', text: '只分享這段文字', topic: '毛孩到家', mediaIds: e.mediaIds, confirmed: true});
async function share(uid = 'a', image = false) {
  const pid = await pet(uid), mediaIds = image ? [await photo(pid, uid)] : [];
  const e = await entry(pid, {mediaIds}, uid), post = await call('publishCommunityPost', shareData(e), uid);
  return {pid, e, postId: post.postId, mediaIds};
}
test('M2 three distinct days generate attributed text with one model call across concurrent duplicates', async () => {
  const {pid, rows} = await week(), req = request({petId: pid, week: '2026-09-07'});
  await Promise.all([service.handlers.requestWeeklyReview(req), service.handlers.requestWeeklyReview(req)]);
  const result = await call('getWeeklyReview', {petId: pid});
  assert.equal(result.status, 'ready'); assert.equal(calls, 1); assert.equal(result.stats.textDays, 3);
  const source = await call('getWeeklyReviewSource', {petId: pid, entryId: rows[0].entryId});
  assert.equal(source.observation, rows[0].observation);
  await deny(call('getWeeklyReview', {petId: pid}, 'b'), 'not-found');
  await deny(call('getWeeklyReviewSource', {petId: pid, entryId: 'foreign'}), 'not-found');
  assert.equal((await call('listPilotNotifications')).items[0].type, 'review');
  await deny(service.handlers.requestWeeklyReview({...req, data: {...req.data, week: '2026-08-31'}}), 'already-exists');
  assert.equal((await db.doc('users/a').get()).get('points'), 7);
});
test('M2 zero entries, photo-only, same-day text and emergency text never call a model', async () => {
  const pid = await pet();
  assert.equal((await call('requestWeeklyReview', {petId: pid})).status, 'insufficient');
  await entry(pid, {observation: '', action: '', mediaIds: [await photo(pid)]});
  for (let i = 0; i < 3; i++) await entry(pid);
  assert.equal((await call('requestWeeklyReview', {petId: pid})).status, 'insufficient');
  await entry(pid, {occurredAtMs: now - 6 * 86400000, observation: '呼吸困難'});
  await entry(pid, {occurredAtMs: now - 5 * 86400000});
  assert.equal((await call('requestWeeklyReview', {petId: pid})).status, 'safety');
  assert.equal(calls, 0);
});
test('M2 edit/delete invalidates AI immediately and removes stale notifications', async () => {
  const {pid, rows} = await week(); await call('requestWeeklyReview', {petId: pid});
  await call('upsertJournalEntry', {...rows[0], expectedRevision: 1, observation: '更新觀察'});
  const read = await call('getWeeklyReview', {petId: pid});
  assert.equal(read.status, 'invalidated'); assert.equal(read.result, null);
  assert.equal((await call('listPilotNotifications')).items.length, 0);
  await call('requestWeeklyReview', {petId: pid});
  await call('deleteJournalEntry', {petId: pid, entryId: rows[0].entryId, expectedRevision: 2});
  assert.equal((await call('getWeeklyReview', {petId: pid})).result, null);
});
test('M2 invalid citations and provider failure consume at most two attempts; repeated operation does not retry', async () => {
  const {pid} = await week();
  provider = async ({input}) => { const result = output(input); result.result.observations[0].entryIds = ['foreign']; return result; };
  const req = request({petId: pid});
  assert.equal((await service.handlers.requestWeeklyReview(req)).status, 'failed');
  await service.handlers.requestWeeklyReview(req); assert.equal(calls, 1);
  provider = async () => { throw Error('private provider failure'); };
  assert.equal((await call('requestWeeklyReview', {petId: pid})).attempts, 2);
  await deny(call('requestWeeklyReview', {petId: pid}), 'resource-exhausted'); assert.equal(calls, 2);
});
test('M2 trial boundary, consent, independent flags and opt-out cannot change membership or extend trial', async () => {
  const {pid} = await week(), p = db.doc('pilotParticipants/a'), until = (await p.get()).get('trialEndsAt').toMillis();
  await call('requestWeeklyReview', {petId: pid});
  await call('setReviewPreference', {enabled: false});
  assert.equal((await call('getWeeklyReview', {petId: pid})).status, 'ready');
  assert.equal((await call('getWeeklyReview', {petId: pid})).canGenerate, false);
  await call('setReviewPreference', {enabled: true, consentVersion: 'weekly-review-v1'});
  assert.equal((await p.get()).get('trialEndsAt').toMillis(), until);
  await p.update({trialEndsAt: stamp(now)});
  await deny(call('requestWeeklyReview', {petId: pid, week: '2026-08-31'}));
  assert.equal((await call('getWeeklyReview', {petId: pid})).status, 'ready');
  assert.equal((await db.doc('users/a').get()).get('membershipTier'), 'free');
  await entry(pid, {occurredAtMs: now - 1000});
  await db.doc('pilotConfig/features').update({journalEnabled: false});
  await p.update({trialEndsAt: stamp(now + 86400000)});
  assert.equal((await call('getWeeklyReview', {petId: pid})).canGenerate, true);
});
test('M2 deletion, editing and preference changes while provider runs prevent late AI writes', async () => {
  for (const uid of ['a', 'b', 'c']) {
    const {pid, rows} = await week(uid);
    provider = async ({input}) => {
      if (uid === 'a') await call('deleteJournalPet', {petId: pid}, uid);
      if (uid === 'b') await call('upsertJournalEntry', {...rows[0], expectedRevision: 1, observation: '更正'}, uid);
      if (uid === 'c') { await call('setReviewPreference', {enabled: false}, uid); await call('setReviewPreference', {enabled: true, consentVersion: 'weekly-review-v1'}, uid); }
      return output(input);
    };
    if (uid === 'a') await deny(call('requestWeeklyReview', {petId: pid}, uid), 'not-found');
    else assert.equal((await call('requestWeeklyReview', {petId: pid}, uid)).result, null);
    assert.notEqual((await petRef(pid, uid).collection('weeklyReviews').doc('2026-09-07').get()).get('status'), 'ready');
  }
});
test('M2 global quota is atomic; abandoned worker leases can recover without an extra third attempt', async () => {
  const {pid} = await week();
  await db.doc('_weeklyReviewLimits/daily').set({day: '2026-09-14', count: 50});
  await deny(call('requestWeeklyReview', {petId: pid}), 'resource-exhausted'); assert.equal(calls, 0);
  await db.doc('_weeklyReviewLimits/daily').set({day: '2026-09-14', count: 0});
  await petRef(pid).collection('weeklyReviews').doc('2026-09-07').set({status: 'processing', leaseId: 'dead-worker', leaseUntil: stamp(now - 1), attempts: 1});
  assert.equal((await call('requestWeeklyReview', {petId: pid})).attempts, 2); assert.equal(calls, 1);
});
test('M2 scheduled enqueue is idempotent, uses prior week, and worker retries failed generation', async () => {
  const {pid} = await week();
  await service.reviews.enqueue(); await service.reviews.enqueue();
  const jobs = await db.collection('_weeklyReviewJobs').get(); assert.equal(jobs.size, 1); assert.equal(jobs.docs[0].get('week'), '2026-09-07');
  provider = async () => { throw Error('timeout'); }; await service.reviews.work();
  assert.equal((await jobs.docs[0].ref.get()).get('state'), 'pending');
  now += 600001; provider = async ({input}) => output(input); await service.reviews.work();
  assert.equal((await call('getWeeklyReview', {petId: pid})).status, 'ready'); assert.equal(calls, 2);
});
test('M3 independent share copy hides private names, preserves source edits and private image paths', async () => {
  const s = await share('a', true), req = {postId: s.postId, mediaId: s.mediaIds[0]};
  const post = await call('getCommunityPost', {postId: s.postId}, 'b');
  assert.equal(post.text, '只分享這段文字'); assert.ok(!JSON.stringify(post).includes('PRIVATE')); assert.ok(!JSON.stringify(post).includes('authorId'));
  const image = await call('getCommunityImage', req, 'b'); assert.equal((await sharp(Buffer.from(image.base64, 'base64')).metadata()).format, 'jpeg');
  await call('upsertJournalEntry', {...s.e, expectedRevision: 1, observation: '私密更新', mediaIds: []});
  await service.sweep();
  assert.equal((await call('getCommunityPost', {postId: s.postId}, 'b')).text, post.text);
  assert.equal((await call('getCommunityImage', req, 'b')).base64, image.base64);
  const [metadata] = await bucket.file(`communityImages/a/${s.postId}/${s.mediaIds[0]}.jpg`).getMetadata();
  assert.ok(!metadata.metadata?.firebaseStorageDownloadTokens);
});
test('M3 publishing requires source ownership, current revision, selected photos and explicit preview confirmation', async () => {
  const pid = await pet(), e = await entry(pid), d = shareData(e);
  await deny(call('publishCommunityPost', d, 'b'), 'not-found');
  await deny(call('publishCommunityPost', {...d, expectedRevision: 2}), 'aborted');
  await deny(call('publishCommunityPost', {...d, confirmed: false}), 'invalid-argument');
  await deny(call('publishCommunityPost', {...d, mediaIds: ['foreign']}), 'invalid-argument');
  const req = request(d); await service.handlers.publishCommunityPost(req); await service.handlers.publishCommunityPost(req);
  assert.equal((await db.collection('communityPosts').get()).size, 1);
});
test('M3 source deletion and withdrawal immediately revoke images and cleanup removes only copies', async () => {
  const a = await share('a', true), b = await share('b', true);
  await call('deleteJournalEntry', {petId: a.pid, entryId: a.e.entryId, expectedRevision: 1});
  await deny(call('getCommunityPost', {postId: a.postId}, 'b'), 'not-found');
  await deny(call('getCommunityImage', {postId: a.postId, mediaId: a.mediaIds[0]}, 'b'), 'not-found');
  await call('withdrawCommunityPost', {postId: b.postId, expectedRevision: 1}, 'b');
  await service.sweep();
  assert.equal((await bucket.getFiles({prefix: 'communityImages/'}))[0].length, 0);
  assert.ok((await call('getJournalImage', {mediaId: b.mediaIds[0]}, 'b')).base64);
});
test('M3 two invited accounts interact; comments and encouragements are idempotent and notifications aggregate', async () => {
  const {postId} = await share();
  const req = request({postId, text: '今天也辛苦了', alias: '同伴乙'}, 'b');
  await Promise.all([service.handlers.addCommunityComment(req), service.handlers.addCommunityComment(req)]);
  await Promise.all([call('encourageCommunityPost', {postId}, 'b'), call('encourageCommunityPost', {postId}, 'b')]);
  await call('encourageCommunityPost', {postId}, 'c');
  const post = await call('getCommunityPost', {postId}); assert.equal(post.commentCount, 1); assert.equal(post.encouragementCount, 2);
  const notes = (await call('listPilotNotifications')).items;
  assert.equal(notes.filter(n => n.type === 'encouragement').length, 1); assert.equal(notes.find(n => n.type === 'encouragement').count, 2);
  await deny(call('addCommunityComment', {postId, alias: '同伴', text: 'x'.repeat(501)}, 'b'), 'invalid-argument');
  await deny(call('addCommunityComment', {postId, alias: '同伴', text: '回覆', parentId: 'nested'}, 'b'), 'invalid-argument');
});
test('M3 non-invited, expired, anonymous and deleted accounts cannot read or interact', async () => {
  const s = await share('a', true);
  for (const uid of ['outsider', null]) await deny(call('listCommunityPosts', {}, uid), uid ? 'permission-denied' : 'unauthenticated');
  await db.doc('pilotParticipants/b').update({expiresAt: stamp(now)});
  await deny(call('getCommunityPost', {postId: s.postId}, 'b'));
  await deny(call('getCommunityImage', {postId: s.postId, mediaId: s.mediaIds[0]}, 'b'));
  await db.doc('_deletedUsers/c').set({}); await deny(call('listCommunityPosts', {}, 'c'));
});
test('M3 bilateral block applies to posts, comments, images, notifications and every interaction', async () => {
  const s = await share('a', true), b = await share('b');
  await call('addCommunityComment', {postId: s.postId, alias: '同伴乙', text: '回應'}, 'b');
  await call('encourageCommunityPost', {postId: s.postId}, 'b');
  await call('blockCommunityAuthor', {postId: b.postId});
  assert.equal((await call('listCommunityPosts', {}, 'b')).items.length, 1);
  await deny(call('getCommunityPost', {postId: s.postId}, 'b'), 'not-found');
  await deny(call('getCommunityImage', {postId: s.postId, mediaId: s.mediaIds[0]}, 'b'), 'not-found');
  await deny(call('addCommunityComment', {postId: s.postId, alias: '乙', text: '無法留言'}, 'b'), 'not-found');
  await deny(call('encourageCommunityPost', {postId: s.postId}, 'b'), 'not-found');
  assert.equal((await call('listCommunityComments', {postId: s.postId})).items.length, 0);
  assert.equal((await call('listPilotNotifications')).items.length, 0);
  const blocks = await call('listCommunityBlocks'); await call('unblockCommunityAuthor', {blockId: blocks.items[0].id});
  assert.equal((await call('listCommunityPosts', {}, 'b')).items.length, 2);
});
test('M3 per-day quotas and edit revisions are server-enforced without client count authority', async () => {
  const s = await share();
  await deny(call('editCommunityPost', {postId: s.postId, expectedRevision: 1, topic: '毛孩到家', text: '越權'}, 'b'));
  await call('editCommunityPost', {postId: s.postId, expectedRevision: 1, topic: '熟悉彼此', text: '更新'});
  await deny(call('editCommunityPost', {postId: s.postId, expectedRevision: 1, topic: '熟悉彼此', text: '舊版'}), 'aborted');
  await db.doc('users/a/communityLimits/posts').set({day: '2026-09-14', count: 5});
  await deny(call('publishCommunityPost', shareData(s.e)), 'resource-exhausted');
  await db.doc('users/b/communityLimits/comments').set({day: '2026-09-14', count: 30});
  await deny(call('addCommunityComment', {postId: s.postId, text: '超額', alias: '乙'}, 'b'), 'resource-exhausted');
});
test('M3 admin custom claim controls reports, moderation, suspension and flags without private data', async () => {
  const s = await share(), admin = {pilotAdmin: true};
  await call('reportCommunityContent', {postId: s.postId, reason: '不適當內容'}, 'b');
  await deny(call('adminGetPilotDashboard', {}, 'b', {isAdmin: true}));
  const listing = await call('adminListPilotData', {kind: 'reports'}, 'admin', admin), r = listing.items[0];
  assert.ok(!JSON.stringify(listing).includes('PRIVATE')); assert.equal(r.text, '只分享這段文字');
  await call('adminModerateCommunity', {reportId: r.id, expectedRevision: 1, contentRevision: 1, action: 'hide', reason: '請修改'}, 'admin', admin);
  await deny(call('getCommunityPost', {postId: s.postId}, 'b'), 'not-found');
  await call('adminModerateCommunity', {reportId: r.id, expectedRevision: 2, contentRevision: 2, action: 'restore', reason: '已確認'}, 'admin', admin);
  assert.equal((await call('getCommunityPost', {postId: s.postId}, 'b')).status, 'published');
  await call('adminSetPostingSuspended', {uid: 'a', suspended: true, reason: '暫停互動'}, 'admin', admin);
  await deny(call('encourageCommunityPost', {postId: s.postId}));
  await call('reportCommunityContent', {postId: s.postId, reason: '仍能檢舉'});
  await call('adminSetPilotFlags', {flags: {communityWriteEnabled: false}}, 'admin', admin);
  assert.equal((await call('listCommunityPosts', {}, 'b')).items.length, 1);
  await deny(call('addCommunityComment', {postId: s.postId, text: '暫停', alias: '乙'}, 'b'));
  assert.ok((await call('adminListPilotData', {kind: 'audit'}, 'admin', admin)).items.length >= 4);
  await deny(call('getWeeklyReview', {petId: s.pid}, 'admin', admin), 'not-found');
});
test('M3 Rules deny all direct access even to owner/admin and all shared Storage paths', async () => {
  const s = await share('a', true);
  for (const uid of ['a', 'b', 'admin']) {
    const context = env.authenticatedContext(uid, {pilotAdmin: uid === 'admin'});
    for (const path of [`communityPosts/${s.postId}`, `users/a/journalPets/${s.pid}/weeklyReviews/2026-09-07`, 'users/a/pilotNotifications/forged', 'communityReports/forged', 'pilotConfig/features']) {
      await assertFails(getDoc(doc(context.firestore(), path))); await assertFails(setDoc(doc(context.firestore(), path), {forged: true}));
    }
    const image = ref(context.storage(), `communityImages/a/${s.postId}/${s.mediaIds[0]}.jpg`);
    await assertFails(getBytes(image)); await assertFails(uploadBytes(image, new Uint8Array([1])));
  }
});
test('M3 account deletion hides content immediately and cleans authored shares and foreign comments', async () => {
  const s = await share('a', true), b = await share('b');
  await call('addCommunityComment', {postId: b.postId, text: '待清理留言', alias: '甲'});
  await call('encourageCommunityPost', {postId: b.postId});
  await db.doc('_deletedUsers/a').set({});
  await deny(call('getCommunityPost', {postId: s.postId}, 'b'));
  await deleteLinkedJournals(db, bucket, 'a');
  assert.equal((await db.collection('communityPosts').where('authorId', '==', 'a').get()).size, 0);
  assert.equal((await call('listCommunityComments', {postId: b.postId}, 'b')).items.length, 0);
  assert.equal((await call('getCommunityPost', {postId: b.postId}, 'b')).encouragementCount, 0);
  assert.equal((await bucket.getFiles({prefix: 'communityImages/a/'}))[0].length, 0);
});
test('M3 actual callable transport validates Auth and exposes only shared payloads', async () => {
  const root = `http://127.0.0.1:5101/${projectId}/us-central1/`;
  const signup = await fetch('http://127.0.0.1:9198/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({email: `${randomUUID()}@example.test`, password: 'emulator-test-only', returnSecureToken: true})});
  const u = await signup.json(); assert.ok(u.idToken);
  await db.doc(`users/${u.localId}`).set({uid: u.localId});
  const http = async (name, data, token = u.idToken) => {
    const r = await fetch(root + name, {method: 'POST', headers: {'Content-Type': 'application/json', ...(token ? {Authorization: `Bearer ${token}`} : {})}, body: JSON.stringify({data: {operationId: randomUUID(), ...data}})});
    return {status: r.status, body: await r.json()};
  };
  assert.equal((await http('listCommunityPosts', {}, null)).status, 401);
  assert.equal((await http('listCommunityPosts', {})).status, 403);
  await db.doc(`pilotParticipants/${u.localId}`).set({status: 'invited', expiresAt: stamp(Date.now() + 86400000), activatedAt: stamp(Date.now())});
  const s = await share();
  const response = await http('getCommunityPost', {postId: s.postId}); assert.equal(response.status, 200); assert.equal(response.body.result.text, '只分享這段文字');
  assert.equal((await http('addCommunityComment', {postId: s.postId, alias: 'HTTP 同伴', text: '這是實際 callable 留言'})).status, 200);
  assert.equal((await http('getWeeklyReview', {petId: s.pid})).status, 404);
});
test('M3 time pagination is stable with equal timestamps; filtering continues beyond hidden rows', async () => {
  const s = await share(), template = (await db.doc(`communityPosts/${s.postId}`).get()).data();
  await db.doc(`communityPosts/${s.postId}`).delete();
  for (let i = 0; i < 45; i++) await db.doc(`communityPosts/p${String(i).padStart(3, '0')}`).set({...template, status: i < 20 ? 'hidden' : 'published'});
  const first = await call('listCommunityPosts', {}, 'b'), second = await call('listCommunityPosts', {cursor: first.cursor}, 'b');
  assert.equal(first.items.length, 20); assert.equal(second.items.length, 5);
  assert.equal(new Set([...first.items, ...second.items].map(p => p.id)).size, 25); assert.equal(second.cursor, null);
});
test('M3 admins can moderate only reported share images, and cannot restore a deleted source', async () => {
  const s = await share('a', true), admin = {pilotAdmin: true};
  await call('reportCommunityContent', {postId: s.postId, reason: '圖片需確認'}, 'b');
  const r = (await call('adminListPilotData', {kind: 'reports'}, 'admin', admin)).items[0];
  await call('adminModerateCommunity', {reportId: r.id, expectedRevision: 1, contentRevision: 1, action: 'hide', reason: '暫時隱藏'}, 'admin', admin);
  await deny(call('adminGetReportedImage', {reportId: r.id, mediaId: s.mediaIds[0]}, 'b'));
  assert.ok((await call('adminGetReportedImage', {reportId: r.id, mediaId: s.mediaIds[0]}, 'admin', admin)).base64);
  await call('deleteJournalEntry', {petId: s.pid, entryId: s.e.entryId, expectedRevision: 1});
  await deny(call('adminGetReportedImage', {reportId: r.id, mediaId: s.mediaIds[0]}, 'admin', admin), 'not-found');
  await deny(call('adminModerateCommunity', {reportId: r.id, expectedRevision: 2, contentRevision: 2, action: 'restore', reason: '不能復活'}, 'admin', admin), 'not-found');
});
test('M3 source deletion during image copy cannot publish or strand a late image', async () => {
  const pid = await pet(), mid = await photo(pid), e = await entry(pid, {mediaIds: [mid]});
  const realFile = bucket.file.bind(bucket), wrapped = Object.create(bucket);
  wrapped.file = path => {
    const f = realFile(path);
    if (!path.startsWith('journalImages/')) return f;
    return new Proxy(f, {get(target, prop) {
      if (prop !== 'copy') return Reflect.get(target, prop);
      return async destination => {
        await call('deleteJournalEntry', {petId: pid, entryId: e.entryId, expectedRevision: 1});
        // Finish source cleanup before this deliberately late copy completes.
        await service.community.cleanupSource('a', pid, e.entryId);
        return target.copy(destination);
      };
    }});
  };
  const raced = createJournalService({db, bucket: wrapped, now: () => now});
  await deny(raced.handlers.publishCommunityPost(request(shareData(e))), 'not-found');
  assert.equal((await call('listCommunityPosts', {}, 'b')).items.length, 0);
  await service.sweep(); assert.equal((await bucket.getFiles({prefix: 'communityImages/'}))[0].length, 0);
});
test('M3 comment moderation/deletion filters notifications and preserves encouragement counts', async () => {
  const {postId} = await share(), admin = {pilotAdmin: true};
  const comment = await call('addCommunityComment', {postId, text: '要處理的留言', alias: '乙'}, 'b');
  await call('reportCommunityContent', {postId, commentId: comment.commentId, reason: '留言需處理'}, 'c');
  const r = (await call('adminListPilotData', {kind: 'reports'}, 'admin', admin)).items[0];
  await call('adminModerateCommunity', {reportId: r.id, expectedRevision: 1, contentRevision: 1, action: 'hide', reason: '隱藏留言'}, 'admin', admin);
  assert.equal((await call('listCommunityComments', {postId})).items.length, 0);
  assert.equal((await call('listPilotNotifications')).items.filter(n => n.type === 'comment').length, 0);
  await call('deleteCommunityComment', {postId, commentId: comment.commentId, expectedRevision: 2}, 'b');
  assert.equal((await call('getCommunityPost', {postId})).commentCount, 0);
  await deny(call('adminModerateCommunity', {reportId: r.id, expectedRevision: 2, contentRevision: 3, action: 'restore', reason: '不能復活'}, 'admin', admin), 'aborted');
});
