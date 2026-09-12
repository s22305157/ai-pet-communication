const {createHash} = require('node:crypto');
const {Timestamp} = require('firebase-admin/firestore');
const P = require('./journal_policy');
const stamp = ms => Timestamp.fromMillis(ms);
const json = value => JSON.parse(JSON.stringify(value, (_, v) => v));

function createJournalService({db, bucket, now = Date.now, normalize = P.normalizeImage, reviewProvider}) {
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

  function event(tx, uid, a, kind, operationId) {
    if (!a.p.metricsConsent || a.p.isTest || a.p.isAdmin) return;
    tx.set(userRef(uid).collection('pilotEvents').doc(operationId), {
      type: kind, createdAt: stamp(now()), expiresAt: stamp(now() + 90 * 86400000), schemaVersion: 1});
  }

  const handlers = {};
  require('./journal_pilot_service')({handlers, db, now, access, participantRef, mutate, event});

  handlers.createJournalPet = request => mutate(request, 'createPet', async ({tx, uid, d, a}) => {
    const name = P.text(d.name, 80, true);
    const species = P.text(d.species, 80, true);
    if (!P.FOCUSES.includes(d.focus)) P.fail('invalid-argument', '請選擇目前關注的情境');
    const arrivedAt = d.arrivedAtMs == null ? null : stamp(P.time(d.arrivedAtMs, now()));
    if (a.p.journalPetId) {
      const active = await tx.get(petRef(uid, a.p.journalPetId));
      if (active.exists && !active.get('deletedAt')) P.fail('already-exists', '每人提供一份有效日記毛孩資料');
    }
    let linkedPetId = null;
    if (d.linkedPetId) {
      linkedPetId = P.id(d.linkedPetId);
      const [pet, tombstone] = await Promise.all([tx.get(db.doc(`pets/${linkedPetId}`)), tx.get(db.doc(`petTombstones/${linkedPetId}`))]);
      if (!pet.exists || pet.get('owner_id') !== uid || tombstone.exists) P.fail('permission-denied', '無法連結此毛孩');
    }
    const ref = userRef(uid).collection('journalPets').doc();
    tx.create(ref, {name, species, focus: d.focus, arrivedAt, linkedPetId,
      entryCount: 0, usedBytes: 0, reservedBytes: 0, pendingUploads: 0, revision: 1, createdAt: stamp(now()), schemaVersion: 1});
    // Serialize concurrent creates against the participant document, even on empty queries.
    tx.update(participantRef(uid), {journalPetId: ref.id});
    event(tx, uid, a, 'pet_created', d.operationId);
    return {petId: ref.id};
  });

  require('./journal_entry_service')({handlers, db, now, access, livePet, mediaRef, mutate, event});

  require('./journal_media_service')({handlers, db, bucket, now, normalize, access, livePet, mediaRef, petRef, mutate});

  handlers.getJournalHome = async request => {
    const uid = request.auth?.uid;
    if (!uid) P.fail('unauthenticated', '請先登入');
    return db.runTransaction(async tx => {
      const a = await access(tx, uid);
      if (!a.p.journalPetId) return {pet: null};
      const current = await tx.get(petRef(uid, a.p.journalPetId));
      if (!current.exists || current.get('deletedAt')) return {pet: null};
      const pet = await livePet(tx, uid, current.id);
      const today = P.dayKey(now());
      const local = new Date(`${today}T00:00:00+08:00`);
      const weekday = new Date(now() + 8 * 3600000).getUTCDay();
      const monday = local.getTime() - ((weekday + 6) % 7) * 86400000;
      const entries = await tx.get(pet.ref.collection('entries').where('occurredAt', '>=', stamp(monday)).limit(300));
      const reviews = await tx.get(pet.ref.collection('weeklyReviews').orderBy('week', 'desc').limit(1));
      return {pet: {id: pet.id, name: pet.get('name'), species: pet.get('species'), focus: pet.get('focus'), entryCount: pet.get('entryCount'),
        usedBytes: pet.get('usedBytes'), reservedBytes: pet.get('reservedBytes')},
      latestReviewWeek: reviews.docs[0]?.id || null,
      weekDays: new Set(entries.docs.map(s => P.dayKey(P.millis(s.get('occurredAt'))))).size};
    });
  };

  const context = {handlers, db, bucket, now, access, livePet, mutate, event};
  const reviews = require('./weekly_review_service')({...context, reviewProvider});
  const community = require('./community_service')(context);
  const {sweep, markPetDeleted, cleanupPet} = require('./journal_cleanup_service')({db, bucket, now, userRef, mediaRef, petRef, handlers, mutate, community});
  return {handlers, sweep: async () => { await sweep(); await community.sweep(); }, markPetDeleted, cleanupPet, reviews, community};
}
module.exports = {createJournalService};
