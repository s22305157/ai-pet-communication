const {onSchedule} = require('firebase-functions/v2/scheduler');
const {getFirestore} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const {runCommunicationPhotoCleanup} = require('./communication_photo_cleanup');

exports.cleanupCommunicationPhotos = onSchedule({schedule: 'every 60 minutes',
  timeZone: 'Asia/Taipei', maxInstances: 1, concurrency: 1, timeoutSeconds: 540, retryCount: 3},
async () => runCommunicationPhotoCleanup({db: getFirestore(), bucket: getStorage().bucket()}));
