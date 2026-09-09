const {Timestamp} = require('firebase-admin/firestore');

function millis(value) {
  return value && typeof value.toMillis === 'function' ? value.toMillis() : 0;
}

// Never grant paid access from a bare, possibly legacy, tier string.
function effectiveTier(user, now = Date.now()) {
  if (user.subscriptionVerified !== true) return 'free';
  for (const tier of ['pro', 'plus']) {
    if (millis(user.membershipEntitlements?.[tier]) > now) return tier;
  }
  return 'free';
}

function subscriberPatch(payload, now = Date.now(), allowSandbox = false) {
  const subscriber = payload?.subscriber;
  if (!subscriber || !subscriber.entitlements || !subscriber.subscriptions ||
      !Number.isFinite(payload.request_date_ms)) throw new Error('Invalid subscriber response');
  const entitlements = {};
  let willRenew = false;
  for (const tier of ['pro', 'plus']) {
    const entitlement = subscriber.entitlements[tier];
    if (!entitlement) continue;
    const subscription = subscriber.subscriptions[entitlement.product_identifier];
    if (!subscription || (!allowSandbox && subscription.is_sandbox !== false)) continue;
    const expires = Date.parse(entitlement.expires_date);
    const grace = Date.parse(subscription.grace_period_expires_date);
    // Monthly products must have a finite end; missing/malformed dates fail closed.
    if (!Number.isFinite(expires)) continue;
    const until = Math.max(expires, Number.isFinite(grace) ? grace : 0);
    entitlements[tier] = Timestamp.fromMillis(until);
  }
  const tier = effectiveTier({subscriptionVerified: true, membershipEntitlements: entitlements}, now);
  if (tier !== 'free') {
    const subscription = subscriber.subscriptions[subscriber.entitlements[tier].product_identifier];
    willRenew = !subscription.unsubscribe_detected_at && !subscription.billing_issues_detected_at;
  }
  return {subscriptionVerified: true, membershipEntitlements: entitlements,
    membershipTier: tier, membershipExpiresAt: entitlements[tier] || null,
    subscriptionWillRenew: willRenew, subscriptionStatus: tier === 'free' ? 'expired' : 'active',
    subscriptionCheckedAt: Timestamp.fromMillis(now),
    subscriptionSnapshotAt: Timestamp.fromMillis(payload.request_date_ms)};
}

// Both inputs are server-owned. Materialize grants into the same expiring
// entitlement map consumed by clients, AI and database rules.
function withManualGrants(patch, user, now = Date.now()) {
  const entitlements = {...patch.membershipEntitlements};
  for (const tier of ['pro', 'plus']) {
    const grant = user.manualMembershipEntitlements?.[tier];
    if (millis(grant) > millis(entitlements[tier])) entitlements[tier] = grant;
  }
  const merged = {...patch, membershipEntitlements: entitlements};
  const tier = effectiveTier(merged, now);
  return {...merged, membershipTier: tier, membershipExpiresAt: entitlements[tier] || null,
    subscriptionStatus: tier === 'free' ? 'expired' : 'active'};
}

module.exports = {effectiveTier, subscriberPatch, millis, withManualGrants};
