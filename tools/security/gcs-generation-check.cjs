// Opt-in real GCS verification. Never run this from the emulator/CI test suite.
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
const {randomBytes, createHash} = require('node:crypto');
const backend = require('node:module').createRequire(path.join(__dirname, '../../functions/package.json'));
const {Storage} = backend('@google-cloud/storage');
// Resolve the auth implementation used by Storage itself. Other Firebase
// dependencies use a newer auth major with an incompatible Headers shape.
const storageDependencies = require('node:module').createRequire(backend.resolve('@google-cloud/storage'));
const {GoogleAuth} = storageDependencies('google-auth-library');
const {sweepCommunicationPhotos} = require('../../functions/communication_photo_cleanup');
const {PHOTO_TTL_MS} = require('../../functions/communication_photo_policy');
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const purpose = 'gcs-generation-test';
const safeError = error => ({name: error.name, code: error.code || null,
  message: error.name === 'AssertionError' ? error.message : 'Cloud operation failed; credentials and request details omitted'});

async function verifyGcsGenerations({projectId, authClient, reportPath}) {
  assert.match(projectId || '', /^pawlink-gcs-test-\d{6}-[a-z0-9]{4,8}$/,
    'Requires a dedicated pawlink-gcs-test project; production projects are not allowed');
  for (const key of ['STORAGE_EMULATOR_HOST', 'FIREBASE_STORAGE_EMULATOR_HOST', 'FIRESTORE_EMULATOR_HOST']) {
    assert.equal(process.env[key], undefined, `Remove ${key} before real GCS verification`);
  }
  const project = (await authClient.request({url:
    `https://cloudresourcemanager.googleapis.com/v1/projects/${projectId}`})).data;
  assert.equal(project.projectId, projectId);
  assert.equal(project.lifecycleState, 'ACTIVE');
  assert.equal(project.labels?.purpose, purpose, 'Project must be explicitly labelled for this test');
  const runId = randomBytes(6).toString('hex');
  const report = {startedAt: new Date().toISOString(), projectId, projectNumber: project.projectNumber,
    runId, endpoint: 'https://storage.googleapis.com', checks: [], buckets: [], cleanup: [],
    firestore: 'Synthetic empty-operation fixture; no cloud Firestore accessed'};
  const storage = new Storage({projectId, authClient, retryOptions: {maxRetries: 2, totalTimeout: 60}});
  const planned = [];
  let failure;
  const persist = () => { if (reportPath) fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n'); };
  const check = async (name, versioning, body) => {
    const evidence = await body();
    report.checks.push({name, versioning, status: 'passed', ...evidence});
    persist();
    console.log(`PASS versioning=${versioning}: ${name}`);
  };
  try {
    for (const versioning of [false, true]) {
      const name = `${projectId}-${runId}-${versioning ? 'versions' : 'single'}`;
      const bucket = storage.bucket(name);
      const objectName = `communicationPhotos/cloud-test/${runId}-replacement/0`;
      planned.push({bucket, objectName});
      persist();
      await storage.createBucket(name, {location: 'ASIA-EAST1', storageClass: 'STANDARD',
        versioning: {enabled: versioning}, softDeletePolicy: {retentionDurationSeconds: '0'},
        iamConfiguration: {uniformBucketLevelAccess: {enabled: true}, publicAccessPrevention: 'enforced'},
        labels: {purpose, run_id: runId}});
      const [settings] = await bucket.getMetadata();
      assert.equal(String(settings.projectNumber), String(project.projectNumber));
      assert.equal(settings.labels.run_id, runId);
      assert.equal(!!settings.versioning?.enabled, versioning);
      assert.equal(Number(settings.softDeletePolicy?.retentionDurationSeconds || 0), 0);
      assert.equal(settings.iamConfiguration.publicAccessPrevention, 'enforced');
      assert.equal(settings.iamConfiguration.uniformBucketLevelAccess.enabled, true);
      report.buckets.push({name, versioning, softDeleteRetentionSeconds: 0,
        publicAccessPrevention: 'enforced', uniformBucketLevelAccess: true});
      persist();
      const oldBytes = Buffer.from(`Synthetic old GCS generation fixture ${runId}`);
      const newBytes = Buffer.from(`Synthetic replacement GCS generation fixture ${runId}`);
      const file = bucket.file(objectName);
      await file.save(oldBytes, {resumable: false, preconditionOpts: {ifGenerationMatch: 0},
        metadata: {contentType: 'application/octet-stream'}});
      const [old] = await file.getMetadata();
      await check('wrong generation precondition returns HTTP 412 and preserves bytes', versioning, async () => {
        await assert.rejects(bucket.file(objectName, {preconditionOpts:
          {ifGenerationMatch: (BigInt(old.generation) + 1n).toString()}}).delete(), error => Number(error.code) === 412);
        assert.equal(hash((await file.download())[0]), hash(oldBytes));
        return {httpStatus: 412, generation: old.generation, sha256: hash(oldBytes)};
      });
      let newer;
      await check('production cleanup preserves a replacement uploaded after listing', versioning, async () => {
        let replaced = false;
        let deleteCalls = 0;
        // Only operation state is synthetic. Listing, overwrite, conditional
        // deletion, metadata and byte downloads all use the real GCS service.
        const db = {collection: collection => {
          assert.equal(collection, 'users');
          return {doc: uid => {
            assert.equal(uid, 'cloud-test');
            return {collection: child => {
              assert.equal(child, 'aiRequests');
              return {doc: id => {
                assert.equal(id, `${runId}-replacement`);
                return {get: async () => ({get: () => undefined})};
              }};
            }};
          }};
        }};
        const observedBucket = {getFiles: async options => {
          const listed = await bucket.getFiles(options);
          assert.equal(listed[0].length, 1);
          assert.equal(listed[0][0].metadata.generation, old.generation);
          assert.equal(replaced, false);
          replaced = true;
          await file.save(newBytes, {resumable: false, preconditionOpts: {ifGenerationMatch: old.generation},
            metadata: {contentType: 'application/octet-stream'}});
          [newer] = await file.getMetadata();
          assert.notEqual(newer.generation, old.generation);
          return listed;
        }, file: (target, options) => {
          assert.equal(target, objectName);
          assert.equal(options.generation, old.generation);
          assert.equal(options.preconditionOpts.ifGenerationMatch, old.generation);
          const pinned = bucket.file(target, options);
          return {delete: async deleteOptions => { deleteCalls++; return pinned.delete(deleteOptions); }};
        }};
        const result = await sweepCommunicationPhotos({db, bucket: observedBucket,
          now: () => Date.parse(old.timeCreated) + PHOTO_TTL_MS + 1});
        assert.equal(deleteCalls, 1);
        const [current] = await file.getMetadata();
        assert.equal(current.generation, newer.generation);
        assert.equal(hash((await file.download())[0]), hash(newBytes));
        assert.equal((await bucket.file(objectName, {generation: old.generation}).exists())[0], false);
        return {oldGeneration: old.generation, replacementGeneration: newer.generation,
          replacementSha256: hash(newBytes), oldGenerationAbsent: true, sweepResult: result};
      });
      await check('replaying the deleted old generation returns HTTP 404 and preserves replacement', versioning, async () => {
        await assert.rejects(bucket.file(objectName, {generation: old.generation,
          preconditionOpts: {ifGenerationMatch: old.generation}}).delete(), error => Number(error.code) === 404);
        assert.equal((await file.getMetadata())[0].generation, newer.generation);
        assert.equal(hash((await file.download())[0]), hash(newBytes));
        return {httpStatus: 404, replacementGeneration: newer.generation, sha256: hash(newBytes)};
      });
      await check('matching current generation deletes only the intended object', versioning, async () => {
        await bucket.file(objectName, {generation: newer.generation,
          preconditionOpts: {ifGenerationMatch: newer.generation}}).delete();
        assert.equal((await file.exists())[0], false);
        assert.equal((await bucket.getFiles({versions: true}))[0].length, 0);
        return {deletedGeneration: newer.generation, remainingVersions: 0};
      });
    }
  } catch (error) {
    failure = error;
    report.failure = safeError(error);
  } finally {
    for (const {bucket, objectName} of planned) {
      try {
        if (!(await bucket.exists())[0]) { report.cleanup.push({bucket: bucket.name, absent: true}); continue; }
        const [metadata] = await bucket.getMetadata();
        assert.equal(String(metadata.projectNumber), String(project.projectNumber));
        assert.equal(metadata.labels?.purpose, purpose);
        assert.equal(metadata.labels?.run_id, runId, 'Never clean another run or a pre-existing bucket');
        const [files] = await bucket.getFiles({versions: true});
        assert(files.every(item => item.name === objectName), 'Unexpected data; stop cleanup');
        for (const item of files) {
          await bucket.file(item.name, {generation: item.metadata.generation,
            preconditionOpts: {ifGenerationMatch: item.metadata.generation}}).delete({ignoreNotFound: true});
        }
        assert.equal((await bucket.getFiles({versions: true}))[0].length, 0);
        await bucket.delete();
        assert.equal((await bucket.exists())[0], false);
        report.cleanup.push({bucket: bucket.name, remainingVersions: 0, absent: true});
        console.log(`CLEANED ${bucket.name}`);
      } catch (error) {
        report.cleanup.push({bucket: bucket.name, error: safeError(error)});
        failure ||= error;
      }
    }
    report.finishedAt = new Date().toISOString();
    report.status = failure ? 'failed' : 'passed';
    persist();
  }
  if (failure) throw failure;
  return report;
}
module.exports = {verifyGcsGenerations, safeError};
if (require.main === module) {
  const [projectId, reportPath] = process.argv.slice(2);
  const authClient = new GoogleAuth({projectId, scopes: ['https://www.googleapis.com/auth/cloud-platform']});
  verifyGcsGenerations({projectId, authClient, reportPath}).then(report => {
    console.log(`${report.checks.length} real GCS checks passed; temporary buckets removed.`);
  }).catch(error => { console.error(JSON.stringify(safeError(error))); process.exitCode = 1; });
}
