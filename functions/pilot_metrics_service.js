const {Timestamp} = require('firebase-admin/firestore');
const P = require('./journal_policy');
const {summarize, DAY} = require('./pilot_metrics');
const stamp = ms => Timestamp.fromMillis(ms);
module.exports = function register({handlers, db, now, access, mutate, event, metricAdminIds = async () => []}) {
  const participant = uid => db.doc(`pilotParticipants/${uid}`);
  async function admin(tx, request) {
    if (!request.auth?.uid) P.fail('unauthenticated', '請先登入');
    if (request.auth.token?.pilotAdmin !== true) P.fail('permission-denied', '需要試營運管理權限');
    await access(tx, request.auth.uid);
  }
  handlers.getPilotInterest = async request => {
    if (!request.auth?.uid) P.fail('unauthenticated', '請先登入');
    return db.runTransaction(async tx => {
      const a = await access(tx, request.auth.uid);
      if (!a.p.activatedAt) P.fail('permission-denied', '請先加入試營運');
      return {interested: a.p.upgradeInterested === true, metricsConsent: a.p.metricsConsent === true,
        canExpressInterest: a.invited, cleanupPending: a.p.metricsCleanupPending === true};
    });
  };
  handlers.markPilotPriceViewed = request => mutate(request, 'priceViewed', async ({tx, uid, a}) => {
    if (!a.p.activatedAt || !a.invited) P.fail('permission-denied', '需要有效試營運資格');
    // Stable daily ID: reloads and multiple devices do not inflate views.
    event(tx, uid, a, 'price_viewed', `price_${P.dayKey(now())}`);
    return {saved: true};
  }, {readOnly: true});
  handlers.setPilotInterest = request => mutate(request, 'pilotInterest', async ({tx, uid, d, a}) => {
    if (!a.p.activatedAt || (d.interested === true && !a.invited)) P.fail('permission-denied', '需要有效試營運資格');
    if (typeof d.interested !== 'boolean' || d.priceVersion !== 'pilot-twd199-v1') P.fail('invalid-argument', '請確認價格預告');
    tx.update(participant(uid), {upgradeInterested: d.interested, upgradeInterestUpdatedAt: stamp(now()), priceVersion: d.priceVersion});
    event(tx, uid, a, 'price_viewed', `price_${P.dayKey(now())}`);
    return {saved: true};
  }, {readOnly: true});
  handlers.setPilotMetricsConsent = request => mutate(request, 'metricsConsent', async ({tx, uid, d, a}) => {
    if (!a.p.activatedAt || typeof d.enabled !== 'boolean') P.fail('invalid-argument', '量測設定不正確');
    // Withdrawal immediately removes the person from reports; the scheduled cleanup removes old events.
    // Reconsent waits for that cleanup so previously withdrawn events cannot re-enter reports.
    if (d.enabled && a.p.metricsCleanupPending) P.fail('failed-precondition', '先前量測資料正在清除，請稍後再開啟');
    tx.update(participant(uid), {metricsConsent: d.enabled, ...(!d.enabled ? {metricsCleanupPending: true} : {}),
      ...(d.enabled && !a.p.metricsConsent ? {metricsStartedAt: stamp(now())} : {})});
    return {saved: true};
  }, {readOnly: true});
  async function collect(tx) {
    const people = await tx.get(db.collection('pilotParticipants').limit(501));
    const events = await tx.get(db.collectionGroup('pilotEvents').where('createdAt', '>=', stamp(now() - 90 * DAY)).limit(20001));
    const costs = await tx.get(db.collection('_pilotCosts').where('day', '>=', P.dayKey(now() - 90 * DAY)).limit(92));
    const truncated = people.size > 500 || events.size > 20000 || costs.size > 91;
    const adminIds = new Set(await metricAdminIds(people.docs.map(p => p.id)));
    const tombstones = await Promise.all(people.docs.map(p => tx.get(db.doc(`_deletedUsers/${p.id}`))));
    const metrics = summarize(people.docs.filter((p, i) => !tombstones[i].exists).map(p => ({id: p.id, ...p.data(),
      isAdmin: p.get('isAdmin') === true || adminIds.has(p.id), joined: P.millis(p.get('activatedAt')),
      measuredFrom: P.millis(p.get('metricsStartedAt')),
      interested: p.get('upgradeInterested') === true})), events.docs.map(e => ({uid: e.ref.parent.parent.id,
      type: e.get('type'), at: P.millis(e.get('createdAt')), subject: e.get('subject')})), now());
    const totals = {modelTwd: 0, storageTwd: 0, requests: 0, minutes: 0, recordedDays: costs.size};
    for (const c of costs.docs) for (const key of ['modelTwd', 'storageTwd', 'requests', 'minutes']) totals[key] += c.get(key) || 0;
    return {metrics: truncated ? null : metrics, truncated, costs: totals};
  }
  handlers.adminGetPilotMetrics = request => db.runTransaction(async tx => { await admin(tx, request); return collect(tx); });
  handlers.adminSetPilotCost = request => mutate(request, 'pilotCost', async ({tx, uid, d}) => {
    await admin(tx, request);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(d.day || '') || !Number.isFinite(Date.parse(`${d.day}T00:00:00+08:00`)) ||
      P.dayKey(Date.parse(`${d.day}T00:00:00+08:00`)) !== d.day || d.day > P.dayKey(now()) || d.day < P.dayKey(now() - 90 * DAY)) P.fail('invalid-argument', '請填寫最近 90 天的有效日期');
    const values = {};
    for (const key of ['modelTwd', 'storageTwd', 'requests', 'minutes']) {
      if (!Number.isFinite(d[key]) || d[key] < 0 || d[key] > 1e9 || (['requests', 'minutes'].includes(key) && !Number.isSafeInteger(d[key]))) P.fail('invalid-argument', '成本與用量格式不正確');
      values[key] = d[key];
    }
    const ref = db.doc(`_pilotCosts/${d.day}`), current = await tx.get(ref);
    if ((current.get('revision') || 0) !== d.expectedRevision) P.fail('aborted', '此日期已有成本紀錄，請重新讀取');
    tx.set(ref, {...values, day: d.day, revision: d.expectedRevision + 1, updatedAt: stamp(now())});
    tx.create(db.collection('_pilotAdminAudit').doc(`cost_${uid}_${P.id(d.operationId)}`), {actor: uid,
      action: 'cost', details: {day: d.day}, createdAt: stamp(now()), schemaVersion: 1});
    return {saved: true};
  }, {readOnly: true});
  handlers.adminGetPilotCost = request => db.runTransaction(async tx => {
    await admin(tx, request);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(request.data?.day || '')) P.fail('invalid-argument', '日期不正確');
    const row = await tx.get(db.doc(`_pilotCosts/${request.data.day}`));
    return row.exists ? {revision: row.get('revision'), modelTwd: row.get('modelTwd'), storageTwd: row.get('storageTwd'),
      requests: row.get('requests'), minutes: row.get('minutes')} : {revision: 0, modelTwd: 0, storageTwd: 0, requests: 0, minutes: 0};
  });
  async function sweep() {
    const pending = await db.collection('pilotParticipants').where('metricsCleanupPending', '==', true).limit(100).get();
    for (const p of pending.docs) {
      await db.runTransaction(async tx => {
        const current = await tx.get(p.ref);
        if (!current.exists || !current.get('metricsCleanupPending') || current.get('metricsConsent')) return;
        const rows = await tx.get(db.collection(`users/${p.id}/pilotEvents`).limit(400));
        for (const e of rows.docs) tx.delete(e.ref);
        if (rows.size < 400) tx.update(p.ref, {metricsCleanupPending: false});
      });
    }
    await db.runTransaction(async tx => {
      const report = await collect(tx);
      if (!report.truncated) tx.set(db.doc(`_pilotMetricSnapshots/${P.dayKey(now())}`), {...report, schemaVersion: 1});
    });
  }
  return {sweep};
};
