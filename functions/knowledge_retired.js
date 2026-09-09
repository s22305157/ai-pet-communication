const {onCall, HttpsError} = require('firebase-functions/v2/https');
exports.retrieveKnowledge = onCall({maxInstances: 1}, () => {
  throw new HttpsError('permission-denied', 'Raw knowledge retrieval is unavailable');
});
