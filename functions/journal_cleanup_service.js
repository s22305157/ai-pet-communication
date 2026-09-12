const {Timestamp, FieldValue} = require('firebase-admin/firestore');
const P = require('./journal_policy');
const stamp = ms => Timestamp.fromMillis(ms);
module.exports = function createCleanup({db, bucket, now, userRef, mediaRef, petRef, handlers, mutate, community}) {
  async function cleanupMedia(uid, mid) {
    const mref = mediaRef(uid, mid);
    await db.runTransaction(async tx => {
      const m = await tx.get(mref);
      if (!m.exists || m.get('status') === 'deleted') return;
      if (m.get('entryId') || P.millis(m.get('expiresAt')) > now()) return;
      const p = await tx.get(petRef(uid, m.get('petId')));
      tx.update(mref, {status: 'deleted'});
      if (p.exists) tx.update(p.ref, {reservedBytes: Math.max(0, (p.get('reservedBytes') || 0) - (m.get('status') === 'pending' ? P.LIMITS.imageBytes : 0)),
        pendingUploads: Math.max(0, (p.get('pendingUploads') || 0) - (m.get('status') === 'pending' ? 1 : 0)),
        usedBytes: Math.max(0, (p.get('usedBytes') || 0) - (m.get('status') === 'ready' ? m.get('bytes') : 0))});
    });
    const m = await mref.get();
    if (m.exists && m.get('status') !== 'deleted') return;
    await bucket.file(`journalUploads/${uid}/${mid}`).delete({ignoreNotFound: true});
    await bucket.deleteFiles({prefix: `journalImages/${uid}/${mid}/`});
    if (m.exists) await mref.update({expiresAt: FieldValue.delete()});
    await db.collection('_journalCleanup').doc(`${uid}_${mid}`).delete();
  }

  async function markPetDeleted(uid, petId) {
    const ref = petRef(uid, petId);
    await db.runTransaction(async tx => {
      const pet = await tx.get(ref);
      if (pet.exists) tx.update(ref, {deletedAt: stamp(now())});
      tx.set(db.collection('_journalPetCleanup').doc(`${uid}_${petId}`), {uid, petId, createdAt: stamp(now())});
    });
  }
  async function cleanupPet(uid, petId) {
    await community.cleanupSource(uid, petId);
    const media = await userRef(uid).collection('journalMedia').where('petId', '==', petId).get();
    for (const m of media.docs) {
      await m.ref.update({status: 'deleted'});
      await cleanupMedia(uid, m.id);
      await m.ref.delete();
    }
    await db.recursiveDelete(petRef(uid, petId));
    await db.collection('_journalPetCleanup').doc(`${uid}_${petId}`).delete();
  }
  handlers.deleteJournalPet = request => mutate(request, 'deletePet', async ({tx, uid, d}) => {
    const ref = petRef(uid, d.petId);
    const pet = await tx.get(ref);
    if (!pet.exists) return {deleted: true};
    tx.update(ref, {deletedAt: stamp(now())});
    tx.set(db.collection('_journalPetCleanup').doc(`${uid}_${d.petId}`), {uid, petId: d.petId, createdAt: stamp(now())});
    return {deleted: true};
  }, {readOnly: true});

  async function sweep() {
    let failures = 0;
    const attempt = async task => { try { await task(); } catch (_) { failures++; } };
    const ready = await db.collectionGroup('journalMedia').where('rawCleanupPending', '==', true).limit(500).get();
    for (const m of ready.docs) {
      await attempt(async () => {
        await bucket.file(`journalUploads/${m.ref.parent.parent.id}/${m.id}`).delete({ignoreNotFound: true});
        await m.ref.update({rawCleanupPending: false});
      });
    }
    const media = await db.collectionGroup('journalMedia').where('expiresAt', '<=', stamp(now())).limit(500).get();
    for (const m of media.docs) if (!m.get('entryId')) await attempt(() => cleanupMedia(m.ref.parent.parent.id, m.id));
    const jobs = await db.collection('_journalCleanup').limit(500).get();
    for (const j of jobs.docs) await attempt(() => cleanupMedia(j.get('uid'), j.get('mediaId')));
    const pets = await db.collection('_journalPetCleanup').limit(100).get();
    for (const j of pets.docs) await attempt(() => cleanupPet(j.get('uid'), j.get('petId')));
    const events = await db.collectionGroup('pilotEvents').where('expiresAt', '<=', stamp(now())).limit(500).get();
    for (const e of events.docs) await attempt(() => e.ref.delete());
    if (failures) throw new Error(`Journal cleanup requires retry (${failures} jobs)`);
  }

return {sweep, markPetDeleted, cleanupPet};
};
