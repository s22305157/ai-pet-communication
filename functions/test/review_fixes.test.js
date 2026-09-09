const test = require('node:test');
const assert = require('node:assert/strict');
const {createAccountDeletionService} = require('../account_deletion_service');
const {consumeJournalQuota} = require('../callable_policy');
function harness(failAt = -1) {
  const docs = new Map();
  const calls = [];
  let clock = 1000000, failure = failAt;
  const snap = path => ({exists: docs.has(path), get: key => docs.get(path)?.[key]});
  const stage = async n => { calls.push(n); if (failure === n) { failure = -1; throw Error('injected'); } };
  const ref = path => ({path, delete: async () => {}, set: async value => docs.set(path, value)});
  const db = {collection: name => ({doc: id => ref(`${name}/${id}`), where: () => ({get: async () => { if (name === 'pets') await stage(1); return {docs: []}; }})}),
    recursiveDelete: async () => stage(4),
    runTransaction: async fn => {
      const writes = [];
      const value = await fn({get: async r => snap(r.path), set: (r, v) => writes.push(() => docs.set(r.path, v)),
        update: (r, v) => writes.push(() => docs.set(r.path, {...docs.get(r.path), ...v}))});
      writes.forEach(f => f()); return value;
    }};
  const auth = {revokeRefreshTokens: () => stage(0), deleteUser: () => stage(5)};
  const service = createAccountDeletionService({db, auth, bucket: {deleteFiles: () => stage(2)}, journals: () => stage(3), now: () => clock});
  return {service, docs, calls, db, auth, advance: () => { clock += 600001; }};
}
for (let i = 0; i < 6; i++) test(`account cleanup retries failed stage ${i} before deleting Auth`, async () => {
  const h = harness(i);
  await h.service.enqueue('a');
  assert.ok(h.docs.has('_deletedUsers/a'));
  assert.ok(h.docs.has('_accountDeletionJobs/a'));
  assert.deepEqual(h.calls, []);
  await assert.rejects(h.service.run('a'), /injected/);
  assert.equal(h.docs.get('_accountDeletionJobs/a').stage, i);
  if (i < 5) assert.equal(h.calls.includes(5), false);
  await h.service.run('a');
  assert.equal(h.docs.get('_accountDeletionJobs/a').status, 'complete');
  const count = h.calls.length;
  await h.service.enqueue('a'); await h.service.run('a');
  assert.equal(h.calls.length, count);
});
test('expired worker lease resumes cleanup; active lease is not stolen', async () => {
  const h = harness(); await h.service.enqueue('a');
  Object.assign(h.docs.get('_accountDeletionJobs/a'), {leaseUntil: 1500000, owner: 'old', stage: 2});
  await h.service.run('a'); assert.deepEqual(h.calls, []);
  h.advance(); await h.service.run('a'); assert.deepEqual(h.calls, [2,3,4,5]);
});
test('missing Auth user is safe during cleanup retries', async () => {
  const h = harness();
  h.auth.revokeRefreshTokens = h.auth.deleteUser = async () => { throw Object.assign(Error('missing'), {code: 'auth/user-not-found'}); };
  await h.service.enqueue('a'); await h.service.run('a');
  assert.equal(h.docs.get('_accountDeletionJobs/a').status, 'complete');
});
test('journal quota bounds account and site usage atomically and resets', async () => {
  const h = harness();
  await assert.rejects(consumeJournalQuota(h.db, null, 1000000), {code:'unauthenticated'});
  for (let i=0;i<120;i++) await consumeJournalQuota(h.db, 'a', 1000000);
  await assert.rejects(consumeJournalQuota(h.db, 'a', 1000000), {code:'resource-exhausted'});
  assert.equal(h.docs.get('_journalGlobalLimits/minute').count, 120);
  h.docs.set('_journalGlobalLimits/minute', {windowMs:1000000,count:3000});
  await assert.rejects(consumeJournalQuota(h.db, 'b', 1000000), {code:'resource-exhausted'});
  assert.equal(h.docs.has('_journalRateLimits/b'), false);
  await consumeJournalQuota(h.db, 'a', 1060001);
  assert.equal(h.docs.get('_journalRateLimits/a').count, 1);
});
test('legacy knowledge callable rejects without loading or returning source snippets', async () => {
  const retired = require('../knowledge_retired').retrieveKnowledge;
  for (const auth of [undefined, {uid:'a'}]) await assert.rejects(async () => retired.run({auth, data:{query:'貓'}}), {code:'permission-denied'});
  assert.equal(require('../knowledge_retrieval').retrieveKnowledge, undefined);
});
