// Called only after the original deletion flow has established ownership and
// installed its account/pet tombstone. Jobs survive a failed external cleanup.
async function deleteLinkedJournals(db, bucket, uid, linkedPetId = null) {
  const {createJournalService} = require('./journal_service');
  const service = createJournalService({db, bucket});
  let query = db.collection('users').doc(uid).collection('journalPets');
  if (linkedPetId) query = query.where('linkedPetId', '==', linkedPetId);
  const pets = await query.get();
  for (const pet of pets.docs) await service.markPetDeleted(uid, pet.id);
  for (const pet of pets.docs) await service.cleanupPet(uid, pet.id);
  if (!linkedPetId) {
    await service.community.cleanupAccount(uid);
    await bucket.deleteFiles({prefix: `journalUploads/${uid}/`});
    await bucket.deleteFiles({prefix: `journalImages/${uid}/`});
    await db.collection('pilotParticipants').doc(uid).delete();
  }
}
module.exports = {deleteLinkedJournals};
