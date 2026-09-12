const {createHash, randomUUID} = require('node:crypto');
const {Timestamp, FieldValue} = require('firebase-admin/firestore');
const P = require('./journal_policy');
const R = require('./weekly_review_policy');
const stamp = ms => Timestamp.fromMillis(ms);
module.exports = function createWeeklyReviews({handlers, db, now, access, livePet, mutate, event, reviewProvider}) {
  const user = uid => db.collection('users').doc(uid);
  const auth = request => { if (!request.auth?.uid) P.fail('unauthenticated', '請先登入'); return request.auth.uid; };
  const allowed = a => a.invited && !!a.p.activatedAt && a.config.reviewEnabled === true &&
    a.p.reviewConsentVersion === 'weekly-review-v1' && a.p.reviewAnalysisEnabled === true && P.millis(a.p.trialEndsAt) > now();
  const refFor = (uid, petId, week) => user(uid).collection('journalPets').doc(P.id(petId)).collection('weeklyReviews').doc(week);
  async function entries(tx, pet, range) {
    const rows = await tx.get(pet.ref.collection('entries').where('occurredAt', '>=', stamp(range.start)).where('occurredAt', '<', stamp(range.end)).orderBy('occurredAt').limit(300));
    return rows.docs.filter(s => !s.get('deletedAt')).map(s => ({id: s.id, ...s.data(), occurredAtMs: P.millis(s.get('occurredAt'))}));
  }
  async function validSources(tx, pet, sources, range) {
    const rows = await Promise.all((sources || []).map(s => tx.get(pet.ref.collection('entries').doc(P.id(s.entryId)))));
    return rows.every((e, i) => e.exists && !e.get('deletedAt') && e.get('revision') === sources[i].revision &&
      P.millis(e.get('occurredAt')) >= range.start && P.millis(e.get('occurredAt')) < range.end);
  }
  handlers.setReviewPreference = request => mutate(request, 'reviewPreference', async ({tx, uid, d, a}) => {
    if (typeof d.enabled !== 'boolean' || (d.enabled && (!a.invited || !a.p.activatedAt || d.consentVersion !== 'weekly-review-v1'))) P.fail('invalid-argument', '請閱讀並同意 AI 日記分析說明');
    tx.update(db.doc(`pilotParticipants/${uid}`), {reviewAnalysisEnabled: d.enabled,
      reviewConsentVersion: 'weekly-review-v1', reviewPreferenceRevision: (a.p.reviewPreferenceRevision || 0) + 1});
    return {saved: true};
  }, {readOnly: true});
  handlers.getWeeklyReview = async request => {
    const uid = auth(request), d = request.data || {}, range = R.weekRange(d.week, now());
    return db.runTransaction(async tx => {
      const a = await access(tx, uid);
      const pet = await livePet(tx, uid, d.petId);
      const ref = refFor(uid, pet.id, range.week), saved = await tx.get(ref);
      const prepared = R.prepare(await entries(tx, pet, range), pet.get('species'));
      let status = saved.get('status') || 'not_started';
      let result = null;
      if (status === 'ready') {
        if (await validSources(tx, pet, saved.get('sources'), range)) result = saved.get('result');
        else { status = 'invalidated'; tx.update(ref, {status, result: FieldValue.delete()}); }
      }
      if (status === 'processing' && P.millis(saved.get('leaseUntil')) <= now()) status = 'failed';
      if (prepared.decision.level === 'emergency') { status = 'safety'; result = null; }
      return {week: range.week, status, stats: prepared.stats, result,
        safetyMessage: prepared.decision.level === 'emergency' ? '紀錄中有需要優先留意的身體警訊；若仍在發生，請立即聯絡獸醫。這週只顯示統計。' : '',
        attempts: saved.get('attempts') || 0, canGenerate: allowed(a) && (saved.get('attempts') || 0) < 2,
        analysisEnabled: a.p.reviewAnalysisEnabled === true, trialEndsAtMs: P.millis(a.p.trialEndsAt)};
    });
  };
  handlers.getWeeklyReviewSource = async request => {
    const uid = auth(request), d = request.data || {}, range = R.weekRange(d.week, now());
    return db.runTransaction(async tx => {
      await access(tx, uid);
      const pet = await livePet(tx, uid, d.petId), saved = await tx.get(refFor(uid, pet.id, range.week));
      if (saved.get('status') !== 'ready' || !(saved.get('sources') || []).some(s => s.entryId === d.entryId) ||
          !await validSources(tx, pet, saved.get('sources'), range)) P.fail('not-found', '回顧來源已變更');
      const entry = await tx.get(pet.ref.collection('entries').doc(P.id(d.entryId)));
      return {id: entry.id, observation: entry.get('observation'), action: entry.get('action'), outcome: entry.get('outcome'),
        context: entry.get('context'), occurredAtMs: P.millis(entry.get('occurredAt')), revision: entry.get('revision'), mediaIds: entry.get('mediaIds')};
    });
  };
  handlers.requestWeeklyReview = async request => {
    const uid = auth(request), d = request.data || {}, range = R.weekRange(d.week, now());
    const operationId = P.id(d.operationId), ref = refFor(uid, d.petId, range.week);
    const op = user(uid).collection('reviewOperations').doc(operationId);
    const hash = createHash('sha256').update(JSON.stringify({petId: d.petId, week: range.week})).digest('hex');
    const leaseId = randomUUID();
    const claim = await db.runTransaction(async tx => {
      const a = await access(tx, uid), pet = await livePet(tx, uid, d.petId);
      const previous = await tx.get(op), saved = await tx.get(ref);
      if (previous.exists) {
        if (previous.get('hash') !== hash) P.fail('already-exists', '請勿重用操作編號');
        return null;
      }
      if (!allowed(a)) P.fail('permission-denied', '回顧未開放、未同意分析或試用已到期');
      if (saved.get('status') === 'ready' && await validSources(tx, pet, saved.get('sources'), range)) {
        tx.create(op, {hash, createdAt: stamp(now())}); return null;
      }
      if (saved.get('status') === 'processing' && P.millis(saved.get('leaseUntil')) > now()) {
        tx.create(op, {hash, createdAt: stamp(now())}); return null;
      }
      const prepared = R.prepare(await entries(tx, pet, range), pet.get('species'));
      const attempts = saved.get('attempts') || 0;
      const sourceVersions = prepared.sources.map(s => ({entryId: s.entryId, revision: s.revision}));
      if (prepared.stats.textDays < 3 || prepared.decision.level === 'emergency') {
        tx.set(ref, {week: range.week, status: prepared.decision.level === 'emergency' ? 'safety' : 'insufficient',
          stats: prepared.stats, sources: sourceVersions, sourceIds: sourceVersions.map(s => s.entryId), attempts, schemaVersion: 1, updatedAt: stamp(now())});
        tx.create(op, {hash, createdAt: stamp(now())});
        return null;
      }
      if (attempts >= 2) P.fail('resource-exhausted', '同一週最多兩次模型處理嘗試');
      if (!reviewProvider) P.fail('failed-precondition', '回顧服務尚未設定');
      const quotaRef = db.doc('_weeklyReviewLimits/daily'), quota = await tx.get(quotaRef);
      const day = P.dayKey(now()), count = quota.get('day') === day ? quota.get('count') || 0 : 0;
      if (count >= 50) P.fail('resource-exhausted', '今日回顧額度已用完，請明天再試');
      tx.set(quotaRef, {day, count: count + 1});
      tx.set(ref, {week: range.week, status: 'processing', attempts: attempts + 1, sources: sourceVersions,
        sourceIds: sourceVersions.map(s => s.entryId), stats: prepared.stats, leaseId, leaseUntil: stamp(now() + 120000),
        preferenceRevision: a.p.reviewPreferenceRevision || 0, schemaVersion: 1, updatedAt: stamp(now())});
      tx.create(op, {hash, createdAt: stamp(now())});
      return prepared;
    });
    if (claim) {
      try {
        const output = await reviewProvider({input: claim.input});
        const result = R.validateResult(output.result, claim.sources);
        await db.runTransaction(async tx => {
          const a = await access(tx, uid), pet = await livePet(tx, uid, d.petId), current = await tx.get(ref);
          if (request.auth.token?.pilotAdmin === true) a.p = {...a.p, isAdmin: true};
          if (current.get('leaseId') !== leaseId || current.get('status') !== 'processing') return;
          const valid = await validSources(tx, pet, current.get('sources'), range);
          if (!allowed(a) || current.get('preferenceRevision') !== (a.p.reviewPreferenceRevision || 0) || !valid) {
            tx.update(ref, {status: 'invalidated', result: FieldValue.delete()}); return;
          }
          const usage = {inputTokens: Math.max(0, Number(output.usage?.inputTokens) || 0), outputTokens: Math.max(0, Number(output.usage?.outputTokens) || 0)};
          tx.update(ref, {status: 'ready', result, usage, updatedAt: stamp(now())});
          tx.set(user(uid).collection('pilotNotifications').doc(`review_${pet.id}_${range.week}`), {
            type: 'review', petId: pet.id, week: range.week, read: false, createdAt: stamp(now()), schemaVersion: 1});
          event(tx, uid, a, 'review_generated', `generated_${leaseId}`, `${uid}/${pet.id}/${range.week}/${leaseId}`);
        });
      } catch (_) {
        // A deleted pet/account must never be recreated by a late model response.
        await db.runTransaction(async tx => {
          const current = await tx.get(ref);
          if (current.exists && current.get('leaseId') === leaseId && current.get('status') === 'processing') {
            tx.update(ref, {status: 'failed', result: FieldValue.delete(), updatedAt: stamp(now())});
          }
        });
      }
    }
    return handlers.getWeeklyReview(request);
  };
  handlers.markWeeklyReviewViewed = request => mutate(request, 'reviewViewed', async ({tx, uid, d, a}) => {
    const range = R.weekRange(d.week, now()), pet = await livePet(tx, uid, d.petId);
    const saved = await tx.get(refFor(uid, pet.id, range.week));
    if (saved.get('status') !== 'ready' || !await validSources(tx, pet, saved.get('sources'), range)) P.fail('not-found', '回顧已失效');
    if (!saved.get('firstViewedAt')) tx.update(saved.ref, {firstViewedAt: stamp(now())});
    event(tx, uid, a, 'review_viewed', d.operationId,
      saved.get('leaseId') ? `${uid}/${pet.id}/${range.week}/${saved.get('leaseId')}` : undefined);
    return {saved: true};
  }, {readOnly: true});
  async function enqueue() {
    if ((await db.doc('pilotConfig/features').get()).get('reviewEnabled') !== true) return;
    const range = R.weekRange(null, now());
    let cursor;
    do {
      let q = db.collection('pilotParticipants').orderBy('__name__').limit(100);
      if (cursor) q = q.startAfter(cursor);
      const rows = await q.get(); cursor = rows.size === 100 ? rows.docs.at(-1) : null;
      for (const p of rows.docs) {
        if (p.get('status') !== 'invited' || !p.get('journalPetId') || !p.get('reviewAnalysisEnabled') ||
            P.millis(p.get('expiresAt')) <= now() || P.millis(p.get('trialEndsAt')) <= now()) continue;
        const job = db.collection('_weeklyReviewJobs').doc(`${p.id}_${p.get('journalPetId')}_${range.week}`);
        await db.runTransaction(async tx => { if (!(await tx.get(job)).exists) tx.create(job, {
          uid: p.id, petId: p.get('journalPetId'), week: range.week, state: 'pending', nextAt: stamp(now()), runs: 0, schemaVersion: 1}); });
      }
    } while (cursor);
  }
  async function work() {
    if ((await db.doc('pilotConfig/features').get()).get('reviewEnabled') !== true) return;
    const jobs = await db.collection('_weeklyReviewJobs').where('state', '==', 'pending').where('nextAt', '<=', stamp(now())).limit(10).get();
    // Sequential bounded work stays within the 540-second scheduled function timeout.
    for (const job of jobs.docs) {
      const claimed = await db.runTransaction(async tx => {
        const j = await tx.get(job.ref);
        if (j.get('state') !== 'pending' || P.millis(j.get('nextAt')) > now()) return null;
        tx.update(j.ref, {nextAt: stamp(now() + 600000), runs: (j.get('runs') || 0) + 1}); return j.data();
      });
      if (!claimed) continue;
      let state = 'done', nextAt = now() + 600000;
      try {
        const response = await handlers.requestWeeklyReview({auth: {uid: claimed.uid}, data: {
          petId: claimed.petId, week: claimed.week, operationId: `scheduled_${claimed.petId}_${claimed.week}_${claimed.runs || 0}`}});
        if (response.status === 'processing' || (response.status === 'failed' && response.attempts < 2)) state = 'pending';
      } catch (e) {
        if (['resource-exhausted', 'unavailable'].includes(e.code)) { state = 'pending'; nextAt = now() + 3600000; }
      }
      if ((claimed.runs || 0) >= 47) state = 'failed';
      await job.ref.update({state, nextAt: stamp(nextAt)});
    }
  }
  return {enqueue, work};
};
