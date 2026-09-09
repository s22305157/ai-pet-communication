const {randomUUID} = require('node:crypto');
const {FieldValue} = require('firebase-admin/firestore');

// Every stage is idempotent. A timed-out worker leaves a lease that expires,
// allowing the scheduled recovery worker to resume the last unfinished stage.
function createAccountDeletionService({db, auth, bucket, journals, now = Date.now}) {
  const refFor = uid => db.collection('_accountDeletionJobs').doc(uid);
  const ignoreMissing = async task => {
    try { await task(); } catch (e) { if (e.code !== 'auth/user-not-found') throw e; }
  };
  const stages = [
    async uid => ignoreMissing(() => auth.revokeRefreshTokens(uid)),
    async uid => {
      const pets = await db.collection('pets').where('owner_id', '==', uid).get();
      const tombstones = await db.collection('petTombstones').where('owner_id', '==', uid).get();
      const ids = new Set([...pets.docs, ...tombstones.docs].map(p => p.id));
      for (const id of ids) {
        const pet = {id, ref: db.collection('pets').doc(id)};
        await db.collection('petTombstones').doc(pet.id).set({owner_id: uid, deleted_at: FieldValue.serverTimestamp()});
        await db.recursiveDelete(pet.ref);
      }
    },
    async uid => bucket.deleteFiles({prefix: `pets/${uid}/`}),
    async uid => journals(db, bucket, uid),
    async uid => {
      for (const name of ['_proxyRateLimits', '_knowledgeRateLimits', '_aiRateLimits', '_journalRateLimits']) {
        await db.collection(name).doc(uid).delete();
      }
      await db.recursiveDelete(db.collection('users').doc(uid));
    },
    async uid => ignoreMissing(() => auth.deleteUser(uid)),
  ];
  async function enqueue(uid) {
    await db.runTransaction(async tx => {
      const ref = refFor(uid);
      const job = await tx.get(ref);
      if (job.exists) return;
      tx.set(db.collection('_deletedUsers').doc(uid), {deletedAt: FieldValue.serverTimestamp()});
      tx.set(ref, {stage: 0, status: 'pending', attempts: 0, leaseUntil: 0, createdAt: FieldValue.serverTimestamp()});
    });
    return {accepted: true};
  }
  async function run(uid) {
    const ref = refFor(uid);
    const owner = randomUUID();
    let stage = await db.runTransaction(async tx => {
      const job = await tx.get(ref);
      if (!job.exists || job.get('status') === 'complete' || job.get('leaseUntil') > now()) return null;
      tx.update(ref, {owner, leaseUntil: now() + 600000, status: 'pending', attempts: (job.get('attempts') || 0) + 1});
      return job.get('stage') || 0;
    });
    if (stage === null) return;
    try {
      while (stage < stages.length) {
        await stages[stage](uid);
        stage++;
        await db.runTransaction(async tx => {
          const job = await tx.get(ref);
          if (job.get('owner') !== owner) throw Error('Deletion lease lost');
          tx.update(ref, {stage, ...(stage === stages.length ? {status: 'complete', leaseUntil: 0,
            completedAt: FieldValue.serverTimestamp()} : {})});
        });
      }
    } catch (error) {
      await db.runTransaction(async tx => {
        const job = await tx.get(ref);
        if (job.get('owner') === owner) tx.update(ref, {leaseUntil: 0});
      });
      throw error;
    }
  }
  return {enqueue, run};
}
module.exports = {createAccountDeletionService};
