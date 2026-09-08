const {getAuth} = require("firebase-admin/auth");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {validatePetId, OperationError} = require("./validation");
const {
  ownedAvatarPath,
  hasRecentAuthentication,
} = require("./account_logic");

async function deleteAvatarIfOwned(avatarUrl, uid) {
  const bucket = getStorage().bucket();
  const path = ownedAvatarPath(avatarUrl, uid, bucket.name);
  if (!path) return;
  await bucket.file(path).delete({ignoreNotFound: true});
}

exports.deletePetData = onCall({maxInstances: 20}, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required");
  }

  try {
    const petId = validatePetId(request.data && request.data.petId);
    const avatarUrl = request.data && request.data.avatarUrl;
    const db = getFirestore();
    const petRef = db.collection("pets").doc(petId);
    const tombstoneRef = db.collection("petTombstones").doc(petId);
    const ownedAvatar = await db.runTransaction(async (transaction) => {
      const [pet, existingTombstone, account, deletedAccount] = await Promise.all([
        transaction.get(petRef), transaction.get(tombstoneRef),
        transaction.get(db.collection('users').doc(uid)),
        transaction.get(db.collection('_deletedUsers').doc(uid)),
      ]);
      if (!account.exists || deletedAccount.exists) {
        throw new HttpsError('permission-denied', 'Account is inactive');
      }
      if ((pet.exists && pet.get('owner_id') !== uid) ||
          (existingTombstone.exists && existingTombstone.get('owner_id') !== uid)) {
        throw new HttpsError('permission-denied', 'Pet is owned by another user');
      }
      const avatar = pet.exists ? pet.get('avatar_url') :
        (existingTombstone.exists ? existingTombstone.get('avatar_url') : avatarUrl);
      transaction.set(tombstoneRef, {
        owner_id: uid, deleted_at: FieldValue.serverTimestamp(),
        avatar_url: typeof avatar === 'string' ? avatar : '',
      });
      return avatar;
    });
    await db.recursiveDelete(petRef);
    await deleteAvatarIfOwned(ownedAvatar, uid);
    return {deleted: true, petId};
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    if (error instanceof OperationError) {
      throw new HttpsError(error.code, error.message);
    }
    throw new HttpsError("internal", "Pet deletion failed");
  }
});

exports.deleteOwnAccount = onCall({
  maxInstances: 10,
  timeoutSeconds: 540,
}, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required");
  }
  if (!hasRecentAuthentication(
    request.auth.token && request.auth.token.auth_time,
    Math.floor(Date.now() / 1000),
  )) {
    throw new HttpsError(
      "failed-precondition",
      "Recent authentication required",
    );
  }

  const db = getFirestore();
  const userRef = db.collection("users").doc(uid);
  const tombstoneRef = db.collection("_deletedUsers").doc(uid);

  // 先建立不可由客戶端移除的 tombstone，避免持有舊 ID token 的帳號
  // 刪除後立刻重建 users/{uid} 來重領初始點數。
  await tombstoneRef.set({deletedAt: FieldValue.serverTimestamp()});
  try {
    await getAuth().revokeRefreshTokens(uid).catch((error) => {
      if (error.code !== 'auth/user-not-found') throw error;
    });
    const pets = await db.collection("pets")
      .where("owner_id", "==", uid)
      .get();
    for (const pet of pets.docs) {
      await db.collection("petTombstones").doc(pet.id).set({
        owner_id: uid,
        deleted_at: FieldValue.serverTimestamp(),
      });
      await db.recursiveDelete(pet.ref);
    }
    await getStorage().bucket().deleteFiles({prefix: `pets/${uid}/`});
    await db.collection("_proxyRateLimits").doc(uid).delete();
    await db.recursiveDelete(userRef);
    await getAuth().deleteUser(uid).catch((error) => {
      if (error.code !== 'auth/user-not-found') throw error;
    });
  } catch (error) {
    throw new HttpsError("internal", "Account deletion failed");
  }

  return {deleted: true};
});
