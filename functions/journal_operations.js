const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {getFirestore} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const {createJournalService} = require('./journal_service');
const {defineSecret, defineString} = require('firebase-functions/params');
const {generateReview} = require('./weekly_review_provider');
const reviewKey = defineSecret('OPENAI_API_KEY_PRO');
const reviewModel = defineString('OPENAI_MODEL', {default: 'gpt-5.6-luna'});

const {enforceAppCheck, consumeJournalQuota} = require('./callable_policy');

const service = () => createJournalService({db: getFirestore(), bucket: getStorage().bucket(),
  reviewProvider: args => generateReview({...args, apiKey: reviewKey.value(), model: reviewModel.value()})});
const names = ['getPilotAccess', 'activatePilot', 'createJournalPet', 'upsertJournalEntry',
  'deleteJournalEntry', 'beginJournalUpload', 'finalizeJournalUpload', 'listJournalEntries',
  'getJournalHome', 'exportJournal', 'adminSetPilotParticipant', 'deleteJournalPet', 'uploadJournalBytes', 'getJournalImage', 'cancelJournalUpload',
  'setReviewPreference', 'getWeeklyReview', 'getWeeklyReviewSource', 'requestWeeklyReview', 'markWeeklyReviewViewed',
  'publishCommunityPost', 'listCommunityPosts', 'getCommunityPost', 'editCommunityPost', 'withdrawCommunityPost', 'getCommunityImage',
  'addCommunityComment', 'listCommunityComments', 'deleteCommunityComment', 'encourageCommunityPost', 'reportCommunityContent',
  'blockCommunityAuthor', 'listCommunityBlocks', 'unblockCommunityAuthor', 'listPilotNotifications', 'markPilotNotificationRead',
  'adminGetPilotDashboard', 'adminListPilotData', 'adminSetPilotFlags', 'adminSetPostingSuspended', 'adminModerateCommunity', 'adminGetReportedImage'];
for (const name of names) {
  exports[name] = onCall({enforceAppCheck, maxInstances: 5, timeoutSeconds: 60, memory: '512MiB',
    ...(name === 'requestWeeklyReview' ? {secrets: [reviewKey]} : {})}, async request => {
    request.rawRequest?.res?.setHeader('Cache-Control', 'private, no-store');
    try {
      await consumeJournalQuota(getFirestore(), request.auth?.uid);
      return await service().handlers[name](request);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      // Do not log journal text, photos, credentials or internal storage paths.
      throw new HttpsError('unavailable', '服務暫時無法完成，請稍後重試');
    }
  });
}
exports.cleanupJournalData = onSchedule({schedule: 'every 60 minutes', timeZone: 'Asia/Taipei',
  maxInstances: 1, timeoutSeconds: 540, retryCount: 3}, async () => service().sweep());
exports.enqueueWeeklyReviews = onSchedule({schedule: '30 8 * * 1', timeZone: 'Asia/Taipei',
  maxInstances: 1, timeoutSeconds: 540, retryCount: 3}, async () => service().reviews.enqueue());
exports.processWeeklyReviews = onSchedule({schedule: 'every 5 minutes', timeZone: 'Asia/Taipei', secrets: [reviewKey],
  maxInstances: 1, timeoutSeconds: 540, retryCount: 3}, async () => service().reviews.work());
