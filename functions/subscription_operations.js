const {timingSafeEqual} = require('node:crypto');
const {getFirestore, Timestamp, FieldPath} = require('firebase-admin/firestore');
const {onCall, onRequest, HttpsError} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {defineSecret, defineBoolean} = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const {effectiveTier, subscriberPatch, millis, withManualGrants} = require('./subscription_policy');

const apiKey = defineSecret('REVENUECAT_SECRET_API_KEY');
const webhookToken = defineSecret('REVENUECAT_WEBHOOK_AUTH');
const allowSandbox = defineBoolean('REVENUECAT_ALLOW_SANDBOX', {default: false});

function validUid(uid) {
  return typeof uid === 'string' && uid.length > 0 && uid.length <= 128 &&
    !uid.includes('/') && !uid.startsWith('$RCAnonymousID:');
}

async function fetchSubscriber(uid, key, fetcher = fetch) {
  const response = await fetcher(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}`, {
    headers: {Authorization: `Bearer ${key}`}, signal: AbortSignal.timeout(10000),
  });
  if (!response.ok) throw new Error(`Subscription provider status ${response.status}`);
  return response.json();
}

function createSync({db, fetchCustomer, now = Date.now, sandbox = false}) {
  return async uid => {
    if (!validUid(uid)) return;
    const ref = db.collection('users').doc(uid);
    const deletedRef = db.collection('_deletedUsers').doc(uid);
    // Do not create provider records for non-users or deleted accounts.
    const initial = await ref.get();
    if (!initial.exists || (await deletedRef.get()).exists ||
        initial.get('subscriptionProviderSyncDisabled') === true) return;
    const patch = subscriberPatch(await fetchCustomer(uid), now(), sandbox);
    await db.runTransaction(async tx => {
      const [user, deleted] = await Promise.all([tx.get(ref), tx.get(deletedRef)]);
      if (!user.exists || deleted.exists || user.get('subscriptionProviderSyncDisabled') === true) return;
      if (millis(user.get('subscriptionSnapshotAt')) >= millis(patch.subscriptionSnapshotAt)) return;
      tx.update(ref, {...withManualGrants(patch, user.data(), now()), hadPaidMembership: user.get('hadPaidMembership') === true ||
        ['plus', 'pro'].includes(user.get('membershipTier')) || Object.keys(patch.membershipEntitlements).length > 0});
    });
  };
}

function productionSync() {
  return createSync({db: getFirestore(), fetchCustomer: uid => fetchSubscriber(uid, apiKey.value()),
    sandbox: allowSandbox.value()});
}

async function downgradeExpired(db, ref, now = Date.now()) {
  await db.runTransaction(async tx => {
    const user = await tx.get(ref);
    if (!user.exists) return;
    const data = user.data();
    const tier = effectiveTier(data, now);
    if (tier === data.membershipTier) return;
    tx.update(ref, {membershipTier: tier,
      membershipExpiresAt: data.membershipEntitlements?.[tier] || null,
      hadPaidMembership: data.hadPaidMembership === true || ['plus', 'pro'].includes(data.membershipTier),
      subscriptionStatus: tier === 'free' ? 'expired' : 'active',
      ...(tier === 'free' ? {subscriptionWillRenew: false} : {})});
  });
}

exports.syncSubscription = onCall({secrets: [apiKey], maxInstances: 3}, async request => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', '請先登入');
  const db = getFirestore();
  const userRef = db.collection('users').doc(uid);
  const limitRef = db.collection('_subscriptionSyncLimits').doc(uid);
  await db.runTransaction(async tx => {
    const [user, deleted, limit] = await Promise.all([tx.get(userRef),
      tx.get(db.collection('_deletedUsers').doc(uid)), tx.get(limitRef)]);
    if (!user.exists || deleted.exists) throw new HttpsError('permission-denied', 'Account is inactive');
    if (millis(limit.get('nextAllowedAt')) > Date.now()) throw new HttpsError('resource-exhausted', '請稍後再同步會員狀態');
    tx.set(limitRef, {nextAllowedAt: Timestamp.fromMillis(Date.now() + 10000)});
  });
  try {
    await productionSync()(uid);
    await downgradeExpired(db, userRef);
    return {membershipTier: effectiveTier((await userRef.get()).data() || {})};
  } catch (_) {
    await downgradeExpired(db, userRef);
    throw new HttpsError('unavailable', '會員狀態暫時無法同步，請稍後重試');
  }
});

function authorized(header, secret) {
  if (!secret || typeof header !== 'string') return false;
  const actual = Buffer.from(header);
  const expected = Buffer.from(secret);
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

function webhookHandler({secret, sync}) {
  return async (req, res) => {
    if (req.method !== 'POST') return res.status(405).send('POST required');
    if (!authorized(req.get('authorization'), secret())) return res.status(401).send('Unauthorized');
    const event = req.body?.event;
    if (!event || typeof event.id !== 'string') return res.status(400).send('Invalid event');
    // Re-fetch current state, including both sides of transfers. Never trust event tier/dates.
    const ids = [...new Set([event.app_user_id, event.original_app_user_id,
      ...(Array.isArray(event.aliases) ? event.aliases : []),
      ...(Array.isArray(event.transferred_from) ? event.transferred_from : []),
      ...(Array.isArray(event.transferred_to) ? event.transferred_to : [])].filter(validUid))];
    if (ids.length > 100) return res.status(400).send('Too many identities');
    try {
      await Promise.all(ids.map(sync));
      return res.status(200).send('OK');
    } catch (_) {
      logger.warn('Subscription webhook sync failed');
      return res.status(503).send('Retry later');
    }
  };
}

exports.revenueCatWebhook = onRequest({secrets: [apiKey, webhookToken], maxInstances: 3,
  timeoutSeconds: 60}, (req, res) => webhookHandler({secret: () => webhookToken.value(),
  sync: productionSync()})(req, res));

// A persistent cursor visits every account, including Free accounts whose purchase
// notification was missed. A failed provider call cannot extend expired access.
exports.reconcileSubscriptions = onSchedule({schedule: 'every 15 minutes',
  timeZone: 'Etc/UTC', secrets: [apiKey], timeoutSeconds: 540, maxInstances: 1}, async () => {
  const db = getFirestore();
  const cursorRef = db.collection('_subscriptionJobs').doc('reconcile');
  const cursor = (await cursorRef.get()).get('lastUid');
  let query = db.collection('users').orderBy(FieldPath.documentId()).limit(100);
  if (cursor) query = query.startAfter(cursor);
  const page = await query.get();
  const sync = productionSync();
  for (let i = 0; i < page.docs.length; i += 5) {
    await Promise.all(page.docs.slice(i, i + 5).map(async user => {
      try { await sync(user.id); } catch (_) { logger.warn('Subscription reconciliation needs retry'); }
      await downgradeExpired(db, user.ref);
    }));
  }
  await cursorRef.set({lastUid: page.size === 100 ? page.docs.at(-1).id : null});
});

// Firebase-only expiry enforcement also runs while provider reconciliation is paused.
exports.expireMemberships = onSchedule({schedule: 'every 15 minutes',
  timeZone: 'Etc/UTC', timeoutSeconds: 540, maxInstances: 1}, async () => {
  const db = getFirestore();
  const cursorRef = db.collection('_subscriptionJobs').doc('expiry');
  const cursor = (await cursorRef.get()).get('lastUid');
  let query = db.collection('users').orderBy(FieldPath.documentId()).limit(100);
  if (cursor) query = query.startAfter(cursor);
  const page = await query.get();
  for (let i = 0; i < page.docs.length; i += 5) {
    await Promise.all(page.docs.slice(i, i + 5).map(user => downgradeExpired(db, user.ref)));
  }
  await cursorRef.set({lastUid: page.size === 100 ? page.docs.at(-1).id : null});
});

exports.createSync = createSync;
exports.downgradeExpired = downgradeExpired;
exports.webhookHandler = webhookHandler;
exports.fetchSubscriber = fetchSubscriber;
