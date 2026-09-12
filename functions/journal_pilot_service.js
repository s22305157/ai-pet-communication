const {Timestamp} = require('firebase-admin/firestore');
const P = require('./journal_policy');
const stamp = ms => Timestamp.fromMillis(ms);
module.exports = function register({handlers, db, now, access, participantRef, mutate, event}) {
  handlers.getPilotAccess = async request => {
    const uid = request.auth?.uid;
    if (!uid) P.fail('unauthenticated', '請先登入');
    return db.runTransaction(async tx => {
      const a = await access(tx, uid);
      return {invited: a.invited, enabled: a.config.journalEnabled === true,
        activated: !!a.p.activatedAt, expiresAtMs: P.millis(a.p.expiresAt),
        trialEndsAtMs: P.millis(a.p.trialEndsAt), metricsConsent: a.p.metricsConsent === true,
        reviewEnabled: a.config.reviewEnabled === true, communityEnabled: a.config.communityEnabled === true,
        communityWriteEnabled: a.config.communityWriteEnabled !== false && a.p.postingSuspended !== true,
        reviewAnalysisEnabled: a.p.reviewAnalysisEnabled === true, isAdmin: request.auth.token?.pilotAdmin === true,
        limits: P.LIMITS};
    });
  };
  handlers.activatePilot = request => mutate(request, 'activate', async ({tx, uid, d, a}) => {
    if (d.consentVersion !== 'journal-m1-v1' || typeof d.metricsConsent !== 'boolean') P.fail('invalid-argument', '請閱讀並同意日記說明');
    const fields = {consentVersion: d.consentVersion, metricsConsent: d.metricsConsent, schemaVersion: 1};
    if (!a.p.activatedAt) Object.assign(fields, {activatedAt: stamp(now()), trialEndsAt: stamp(now() + 28 * 86400000)});
    tx.update(participantRef(uid), fields);
    if (!a.p.activatedAt) event(tx, uid, {...a, p: {...a.p, metricsConsent: d.metricsConsent}}, 'activated', d.operationId);
    return {activated: true};
  }, {activation: false});


  handlers.adminSetPilotParticipant = async request => {
    if (!request.auth?.uid || request.auth.token.pilotAdmin !== true) P.fail('permission-denied', '需要試營運管理權限');
    const d = request.data || {};
    const uid = P.id(d.uid);
    const op = P.id(d.operationId);
    if (!['invited', 'disabled'].includes(d.status) || !Number.isSafeInteger(d.expiresAtMs) || d.expiresAtMs <= now()) P.fail('invalid-argument', '資格或期限不正確');
    return db.runTransaction(async tx => {
      await access(tx, request.auth.uid);
      await access(tx, uid);
      const ref = db.collection('_pilotAdminAudit').doc(op);
      const previous = await tx.get(ref);
      const details = {uid, status: d.status, expiresAtMs: d.expiresAtMs, isTest: d.isTest === true};
      if (previous.exists) {
        if (previous.get('actor') !== request.auth.uid || JSON.stringify(previous.get('details')) !== JSON.stringify(details)) P.fail('already-exists', '操作編號已使用');
        return {saved: true};
      }
      tx.set(participantRef(uid), {status: d.status, expiresAt: stamp(d.expiresAtMs), isTest: d.isTest === true, schemaVersion: 1}, {merge: true});
      tx.create(ref, {actor: request.auth.uid, details, createdAt: stamp(now())});
      return {saved: true};
    });
  };

};
