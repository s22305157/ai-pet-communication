const {Timestamp} = require('firebase-admin/firestore');
const P = require('./journal_policy');
const stamp = ms => Timestamp.fromMillis(ms);

module.exports = function register({handlers, db, bucket, now, normalize, access, livePet, mediaRef, petRef, userRef, participantRef, mutate, event}) {
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


};
