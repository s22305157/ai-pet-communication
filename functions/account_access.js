const {HttpsError} = require('firebase-functions/v2/https');
async function assertActiveAccount(db, uid) {
  const [user, deleted] = await Promise.all([
    db.collection('users').doc(uid).get(),
    db.collection('_deletedUsers').doc(uid).get(),
  ]);
  if (!user.exists || deleted.exists) {
    throw new HttpsError('permission-denied', 'Account is inactive');
  }
}
module.exports = {assertActiveAccount};
