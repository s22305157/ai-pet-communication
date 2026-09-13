const {createHash} = require('node:crypto');
const {Timestamp} = require('firebase-admin/firestore');
const P = require('./journal_policy');
const stamp = ms => Timestamp.fromMillis(ms);
const json = value => JSON.parse(JSON.stringify(value));

function createJournalContext({db, bucket, now = Date.now}) {
  const userRef = uid => db.collection('users').doc(uid);
  const participantRef = uid => db.collection('pilotParticipants').doc(uid);
  const petRef = (uid, petId) => userRef(uid).collection('journalPets').doc(P.id(petId));
  const mediaRef = (uid, mediaId) => userRef(uid).collection('journalMedia').doc(P.id(mediaId));

  async function access(tx, uid, write = false, activation = true) {
    const [user, deleted, participant, flags] = await Promise.all([
      tx.get(userRef(uid)), tx.get(db.collection('_deletedUsers').doc(uid)),
      tx.get(participantRef(uid)), tx.get(db.doc('pilotConfig/features'))]);
    if (!user.exists || deleted.exists) P.fail('permission-denied', '帳號已停用');
    const p = participant.data() || {};
    const config = flags.data() || {};
    const invited = p.status === 'invited' && P.millis(p.expiresAt) > now();
    if (write && (!invited || config.journalEnabled !== true || (activation && !p.activatedAt))) P.fail('permission-denied', '毛孩日記尚未開放或資格已到期');
    return {user: user.data(), p, config, invited};
  }

  async function livePet(tx, uid, petId) {
    const ref = petRef(uid, petId);
    const snapshot = await tx.get(ref);
    if (!snapshot.exists || snapshot.get('deletedAt')) P.fail('not-found', '日記毛孩不存在或已刪除');
    if (snapshot.get('linkedPetId')) {
      const tombstone = await tx.get(db.collection('petTombstones').doc(snapshot.get('linkedPetId')));
      if (tombstone.exists) P.fail('not-found', '原毛孩已刪除');
    }
    return snapshot;
  }

  async function mutate(request, name, handler, options = {}) {
    const uid = request.auth?.uid;
    if (!uid) P.fail('unauthenticated', '請先登入');
    const d = request.data || {};
    const opId = P.id(d.operationId);
    const hash = createHash('sha256').update(JSON.stringify({name, d})).digest('hex');
    const op = userRef(uid).collection('journalOperations').doc(opId);
    return db.runTransaction(async tx => {
      const a = await access(tx, uid, !options.readOnly, options.activation !== false);
      if (request.auth.token?.pilotAdmin === true) a.p = {...a.p, isAdmin: true};
      const existing = await tx.get(op);
      if (existing.exists) {
        if (existing.get('hash') !== hash) P.fail('already-exists', '請勿重用操作編號');
        return existing.get('result');
      }
      const rateRef = userRef(uid).collection('journalLimits').doc('operations');
      const rate = await tx.get(rateRef);
      const count = now() - (rate.get('windowMs') || 0) < 60000 ? rate.get('count') || 0 : 0;
      if (count >= 60) P.fail('resource-exhausted', '操作較頻繁，請稍後再試');
      const result = await handler({tx, uid, d, a});
      tx.set(rateRef, {windowMs: count ? rate.get('windowMs') : now(), count: count + 1});
      tx.create(op, {hash, result: json(result), createdAt: stamp(now()), schemaVersion: 1});
      return result;
    });
  }

  function event(tx, uid, a, kind, operationId, subject) {
    if (a.p.metricsConsent !== true || a.p.metricsCleanupPending || a.p.isTest || a.p.isAdmin) return;
    tx.set(userRef(uid).collection('pilotEvents').doc(operationId), {
      type: kind, ...(subject ? {subject: createHash('sha256').update(subject).digest('hex')} : {}),
      createdAt: stamp(now()), expiresAt: stamp(now() + 90 * 86400000), schemaVersion: 2});
  }

  return {db, bucket, now, userRef, participantRef, petRef, mediaRef, access, livePet, mutate, event};
}
module.exports = {createJournalContext};
