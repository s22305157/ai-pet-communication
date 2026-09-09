const {getAuth} = require('firebase-admin/auth');
const {getFirestore} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {createAccountDeletionService} = require('./account_deletion_service');
const {deleteLinkedJournals} = require('./journal_account_cleanup');
const service = () => createAccountDeletionService({db: getFirestore(), auth: getAuth(),
  bucket: getStorage().bucket(), journals: deleteLinkedJournals});
exports.service = service;
exports.processAccountDeletion = onDocumentCreated({document: '_accountDeletionJobs/{uid}',
  retry: true, maxInstances: 3, timeoutSeconds: 540}, event => service().run(event.params.uid));
exports.retryAccountDeletions = onSchedule({schedule: 'every 10 minutes', maxInstances: 1,
  timeoutSeconds: 540, retryCount: 3}, async () => {
  const jobs = await getFirestore().collection('_accountDeletionJobs')
    .where('status', '==', 'pending').orderBy('leaseUntil').limit(10).get();
  const results = await Promise.allSettled(jobs.docs.map(job => service().run(job.id)));
  if (results.some(r => r.status === 'rejected')) throw Error('Account cleanup requires retry');
});
