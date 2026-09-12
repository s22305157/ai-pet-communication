const P = require('./journal_policy');
const DAY = 86400000;
const eligible = p => p.metricsConsent === true && !p.metricsCleanupPending && !p.isAdmin && !p.isTest;
const ratio = (numerator, denominator, pending = 0) => ({numerator, denominator, pending,
  rate: denominator ? numerator / denominator : null});

// Receives metadata only. Neither the result nor archived snapshots contain IDs.
function summarize(participants, events, now) {
  const from = now - 90 * DAY;
  const people = new Map(participants.filter(p => eligible(p)).map(p => [p.id, p]));
  const rows = events.filter(e => people.has(e.uid) && e.at > from && e.at <= now &&
    (!people.get(e.uid).measuredFrom || e.at >= people.get(e.uid).measuredFrom));
  const joined = [...people.values()].filter(p => p.joined > from && p.joined <= now && (!p.measuredFrom || p.measuredFrom <= p.joined));
  const userRows = new Map(), subjects = new Map();
  for (const e of rows) {
    if (!userRows.has(e.uid)) userRows.set(e.uid, []);
    userRows.get(e.uid).push(e);
    if (e.subject) {
      if (!subjects.has(e.subject)) subjects.set(e.subject, []);
      subjects.get(e.subject).push(e);
    }
  }
  const byUser = id => userRows.get(id) || [];
  const mature = joined.filter(p => p.joined + 2 * DAY <= now);
  const retained = joined.filter(p => p.joined + 28 * DAY <= now);
  const activation = ratio(mature.filter(p => byUser(p.id).some(e => e.type === 'entry_created' &&
    e.at >= p.joined && e.at < p.joined + 2 * DAY)).length, mature.length, joined.length - mature.length);
  const retention = ratio(retained.filter(p => new Set(byUser(p.id).filter(e =>
    ['entry_created', 'review_viewed'].includes(e.type) && e.at >= p.joined + 21 * DAY && e.at < p.joined + 28 * DAY)
    .map(e => P.dayKey(e.at))).size >= 2).length, retained.length, joined.length - retained.length);
  function sevenDay(createdType, responseTypes) {
    const created = rows.filter(e => e.type === createdType && e.subject);
    const ready = created.filter(e => e.at + 7 * DAY <= now);
    return ratio(ready.filter(e => subjects.get(e.subject).some(r => responseTypes.includes(r.type) &&
      (createdType === 'review_generated' ? r.uid === e.uid : r.uid !== e.uid) &&
      r.at >= e.at && r.at < e.at + 7 * DAY)).length, ready.length, created.length - ready.length);
  }
  const priceViewers = new Set(rows.filter(e => e.type === 'price_viewed').map(e => e.uid));
  const counts = {};
  for (const e of rows) counts[e.type] = (counts[e.type] || 0) + 1;
  return {fromMs: from, toMs: now, measuredParticipants: people.size,
    incompleteCohorts: [...people.values()].filter(p => p.measuredFrom > p.joined).length, activation, retention,
    reviewViews: sevenDay('review_generated', ['review_viewed']),
    communityResponses: sevenDay('post_created', ['comment_created', 'encouragement_created']),
    upgradeInterest: ratio([...priceViewers].filter(id => people.get(id).interested === true).length, priceViewers.size),
    legacyUnlinkedEvents: rows.filter(e => ['review_generated', 'post_created'].includes(e.type) && !e.subject).length,
    counts};
}
module.exports = {summarize, eligible, DAY};
