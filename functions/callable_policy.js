const {defineBoolean} = require('firebase-functions/params');
const {HttpsError} = require('firebase-functions/v2/https');
const {Timestamp} = require('firebase-admin/firestore');
// Deployment starts in monitor mode; enable after registered clients are verified.
const enforceAppCheck = defineBoolean('ENFORCE_APP_CHECK', {default: false});
async function consumeJournalQuota(db, uid, now = Date.now()) {
  if (!uid) throw new HttpsError('unauthenticated', '請先登入');
  const refs = [db.collection('_journalRateLimits').doc(uid), db.collection('_journalGlobalLimits').doc('minute')];
  await db.runTransaction(async tx => {
    const snapshots = await Promise.all(refs.map(ref => tx.get(ref)));
    const values = snapshots.map((s, i) => {
      const current = now - (s.get('windowMs') || 0) < 60000;
      const count = current ? s.get('count') || 0 : 0;
      if (count >= [120, 3000][i]) throw new HttpsError('resource-exhausted', '操作較頻繁，請稍後再試');
      return {count: count + 1, windowMs: current ? s.get('windowMs') : now,
        expiresAt: Timestamp.fromMillis(now + 120000)};
    });
    refs.forEach((ref, i) => tx.set(ref, values[i]));
  });
}
module.exports = {enforceAppCheck, consumeJournalQuota};
