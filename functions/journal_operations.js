const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {getFirestore} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const {createJournalService} = require('./journal_service');

const {enforceAppCheck, consumeJournalQuota} = require('./callable_policy');

const service = () => createJournalService({db: getFirestore(), bucket: getStorage().bucket()});
const names = ['getPilotAccess', 'activatePilot', 'createJournalPet', 'upsertJournalEntry',
  'deleteJournalEntry', 'beginJournalUpload', 'finalizeJournalUpload', 'listJournalEntries',
  'getJournalHome', 'exportJournal', 'adminSetPilotParticipant', 'deleteJournalPet', 'uploadJournalBytes', 'getJournalImage', 'cancelJournalUpload'];
for (const name of names) {
  exports[name] = onCall({enforceAppCheck, maxInstances: 5, timeoutSeconds: 60, memory: '512MiB'}, async request => {
    request.rawRequest?.res?.setHeader('Cache-Control', 'private, no-store');
    try {
      await consumeJournalQuota(getFirestore(), request.auth?.uid);
      return await service().handlers[name](request);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      // Do not log journal text, photos, credentials or internal storage paths.
      throw new HttpsError('unavailable', '日記服務暫時無法完成，請稍後重試；草稿已保留');
    }
  });
}
exports.cleanupJournalData = onSchedule({schedule: 'every 60 minutes', timeZone: 'Asia/Taipei',
  maxInstances: 1, timeoutSeconds: 540, retryCount: 3}, async () => service().sweep());
