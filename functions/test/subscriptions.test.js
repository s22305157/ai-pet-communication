const test = require('node:test');
const assert = require('node:assert/strict');
const {Timestamp} = require('firebase-admin/firestore');
const {effectiveTier, subscriberPatch, withManualGrants} = require('../subscription_policy');
const {createSync, downgradeExpired, webhookHandler, fetchSubscriber} = require('../subscription_operations');

const now = 1800000000000;
const stamp = value => Timestamp.fromMillis(value);
const iso = value => new Date(value).toISOString();
function customer({until = now + 1000, at = now, sandbox = false, cancelled = false, grace = null} = {}) {
  return {request_date_ms: at, subscriber: {
    entitlements: {pro: {product_identifier: 'monthly', expires_date: iso(until)}},
    subscriptions: {monthly: {is_sandbox: sandbox, grace_period_expires_date: grace && iso(grace),
      unsubscribe_detected_at: cancelled ? iso(now - 1) : null}},
  }};
}
function database(initial = {}) {
  const docs = new Map(Object.entries(initial));
  const snapshot = value => ({exists: value !== undefined, data: () => value, get: key => value?.[key]});
  const ref = path => ({path, get: async () => snapshot(docs.get(path))});
  let tail = Promise.resolve();
  const db = {collection: name => ({doc: id => ref(`${name}/${id}`)}), runTransaction: fn => {
    const result = tail.then(async () => {
      const writes = [];
      await fn({get: async ref => snapshot(docs.get(ref.path)),
        update: (ref, value) => writes.push(() => docs.set(ref.path, {...docs.get(ref.path), ...value})),
      });
      writes.forEach(write => write());
    });
    tail = result.catch(() => {});
    return result;
  }};
  return {db, docs};
}

test('expiry boundary, Pro to Plus fallback and unverified legacy plans fail closed', () => {
  const user = {subscriptionVerified: true, membershipEntitlements: {pro: stamp(now), plus: stamp(now + 1)}};
  assert.equal(effectiveTier(user, now - 1), 'pro');
  assert.equal(effectiveTier(user, now), 'plus');
  assert.equal(effectiveTier(user, now + 1), 'free');
  assert.equal(effectiveTier({membershipTier: 'pro'}, now), 'free');
  assert.equal(effectiveTier({...user, subscriptionVerified: false}, now), 'free');
});

test('administrative grant survives empty provider state and expires without deleting data', async () => {
  const {db, docs} = database({'users/a': {membershipTier: 'pro', points: 42,
    manualMembershipEntitlements: {pro: stamp(now + 100)}}});
  await createSync({db, now: () => now, fetchCustomer: async () => ({request_date_ms: now,
    subscriber: {entitlements: {}, subscriptions: {}}})})('a');
  assert.equal(effectiveTier(docs.get('users/a'), now + 99), 'pro');
  assert.equal(docs.get('users/a').subscriptionWillRenew, false);
  await downgradeExpired(db, db.collection('users').doc('a'), now + 100);
  assert.equal(docs.get('users/a').membershipTier, 'free');
  assert.equal(docs.get('users/a').points, 42);
  assert.equal(docs.get('users/a').hadPaidMembership, true);
});

test('manual-only account never sends identity to provider, including after expiry', async () => {
  const {db, docs} = database({'users/a': {membershipTier: 'pro', subscriptionVerified: true,
    subscriptionProviderSyncDisabled: true, membershipEntitlements: {pro: stamp(now)}}});
  await createSync({db, fetchCustomer: async () => assert.fail('provider must not be called')})('a');
  await downgradeExpired(db, db.collection('users').doc('a'), now);
  assert.equal(docs.get('users/a').membershipTier, 'free');
});

test('grant merging keeps longer paid renewal and falls back to paid Plus after granted Pro', () => {
  const paid = {subscriptionVerified: true, membershipEntitlements: {
    pro: stamp(now + 200), plus: stamp(now + 300)}};
  const merged = withManualGrants(paid, {manualMembershipEntitlements: {pro: stamp(now + 100)}}, now);
  assert.equal(merged.membershipExpiresAt.toMillis(), now + 200);
  assert.equal(effectiveTier(merged, now + 200), 'plus');
  assert.equal(effectiveTier(merged, now + 300), 'free');
});

test('cancellation preserves the paid period; grace extends access only until its end', () => {
  const cancelled = subscriberPatch(customer({cancelled: true}), now);
  assert.equal(cancelled.membershipTier, 'pro');
  assert.equal(cancelled.subscriptionWillRenew, false);
  const grace = subscriberPatch(customer({until: now - 100, grace: now + 10}), now);
  assert.equal(effectiveTier(grace, now + 9), 'pro');
  assert.equal(effectiveTier(grace, now + 10), 'free');
  assert.equal(subscriberPatch(customer({until: now}), now).membershipTier, 'free');
});

test('production refuses sandbox and lifetime/malformed monthly dates', () => {
  assert.equal(subscriberPatch(customer({sandbox: true}), now).membershipTier, 'free');
  assert.equal(subscriberPatch(customer({sandbox: true}), now, true).membershipTier, 'pro');
  for (const date of [null, undefined, 'invalid']) {
    const payload = customer(); payload.subscriber.entitlements.pro.expires_date = date;
    assert.equal(subscriberPatch(payload, now).membershipTier, 'free');
  }
  assert.throws(() => subscriberPatch({}, now));
});

test('duplicate or out-of-order snapshots cannot undo a newer renewal', async () => {
  const {db, docs} = database({'users/a': {membershipTier: 'free'}});
  let payload = customer({at: now + 2, until: now + 10000});
  const sync = createSync({db, now: () => now, fetchCustomer: async () => payload});
  await sync('a');
  const renewed = docs.get('users/a');
  payload = customer({at: now + 1, until: now - 1}); await sync('a');
  assert.deepEqual(docs.get('users/a'), renewed);
  payload = customer({at: now + 2, until: now - 1}); await sync('a');
  assert.deepEqual(docs.get('users/a'), renewed);
  payload = customer({at: now + 3, until: now - 1}); await sync('a');
  assert.equal(docs.get('users/a').membershipTier, 'free');
  assert.equal(docs.get('users/a').hadPaidMembership, true);
});

test('late HTTP completion cannot overwrite the newer provider snapshot', async () => {
  const {db, docs} = database({'users/a': {membershipTier: 'free'}});
  let resolveOld;
  const old = new Promise(resolve => { resolveOld = resolve; });
  const syncOld = createSync({db, now: () => now, fetchCustomer: () => old});
  const pending = syncOld('a');
  await createSync({db, now: () => now,
    fetchCustomer: async () => customer({at: now + 2})})('a');
  resolveOld(customer({at: now + 1, until: now - 1})); await pending;
  assert.equal(docs.get('users/a').membershipTier, 'pro');
});

test('provider outage preserves state; fallback downgrade does not remove user data or points', async () => {
  const {db, docs} = database({'users/a': {membershipTier: 'pro', points: 42,
    displayName: 'A', subscriptionVerified: true, membershipEntitlements: {pro: stamp(now)}}});
  await assert.rejects(createSync({db, fetchCustomer: async () => { throw new Error('offline'); }})('a'));
  assert.equal(docs.get('users/a').membershipTier, 'pro');
  await downgradeExpired(db, db.collection('users').doc('a'), now);
  assert.equal(docs.get('users/a').membershipTier, 'free');
  assert.equal(docs.get('users/a').points, 42);
  assert.equal(docs.get('users/a').displayName, 'A');
  assert.equal(docs.get('users/a').hadPaidMembership, true);
  // Renewal committed before the fallback transaction must survive it.
  Object.assign(docs.get('users/a'), {membershipTier: 'pro', membershipEntitlements: {pro: stamp(now + 10)}});
  await downgradeExpired(db, db.collection('users').doc('a'), now);
  assert.equal(docs.get('users/a').membershipTier, 'pro');
});

test('missing, anonymous, invalid and deleted users are not provisioned by webhook', async () => {
  const {db, docs} = database({'users/a': {}, '_deletedUsers/a': {}});
  const sync = createSync({db, fetchCustomer: async () => { assert.fail('must not fetch'); }});
  for (const uid of ['a', 'missing', '$RCAnonymousID:123', 'bad/id']) await sync(uid);
  assert.equal(docs.size, 2);
});

test('deletion during provider fetch cannot recreate the user', async () => {
  const {db, docs} = database({'users/a': {}});
  await createSync({db, now: () => now, fetchCustomer: async () => {
    docs.delete('users/a'); docs.set('_deletedUsers/a', {}); return customer();
  }})('a');
  assert.equal(docs.has('users/a'), false);
});

test('webhook verifies authorization, deduplicates aliases, handles transfers and retries failures', async () => {
  const seen = [];
  const handler = webhookHandler({secret: () => 'Bearer test-secret', sync: async uid => seen.push(uid)});
  const res = {code: 0, status(code) { this.code = code; return this; }, send() { return this; }};
  const req = {method: 'POST', get: () => 'bad', body: {event: {id: 'event'}}};
  await handler(req, res); assert.equal(res.code, 401); assert.equal(seen.length, 0);
  req.get = () => 'Bearer test-secret';
  req.body.event = {id: 'transfer', app_user_id: 'b', aliases: ['b', '$RCAnonymousID:123'],
    transferred_from: ['a'], transferred_to: ['b']};
  await handler(req, res); assert.equal(res.code, 200); assert.deepEqual(seen.sort(), ['a', 'b']);
  await webhookHandler({secret: req.get, sync: async () => { throw new Error('offline'); }})(req, res);
  assert.equal(res.code, 503);
});

test('HTTP failures, including 404, are not treated as cancellation', async () => {
  await assert.rejects(fetchSubscriber('a', 'secret', async () => ({ok: false, status: 404})));
});
