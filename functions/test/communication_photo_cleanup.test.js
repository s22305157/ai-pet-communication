const test = require('node:test');
const assert = require('node:assert/strict');
const {sweepCommunicationPhotos, runCommunicationPhotoCleanup} = require('../communication_photo_cleanup');
const {PHOTO_TTL_MS, PROCESSING_GRACE_MS} = require('../communication_photo_policy');

const at = Date.UTC(2026, 8, 13);
function fixture(objects, operations = {}) {
  const deleted = [];
  const db = {collection: name => {
    assert.equal(name, 'users');
    return {doc: uid => ({collection: name => {
      assert.equal(name, 'aiRequests');
      return {doc: id => ({get: async () => ({get: key => operations[`${uid}/${id}`]?.[key]})})};
    }})};
  }};
  const bucket = {getFiles: async options => {
    assert.equal(options.prefix, 'communicationPhotos/');
    assert.equal(options.autoPaginate, false);
    return [objects, null];
  }, file: (name, options) => ({delete: async () => {
    assert.equal(options.generation, 'old-generation');
    assert.equal(options.preconditionOpts.ifGenerationMatch, 'old-generation');
    deleted.push(name);
  }})};
  return {db, bucket, deleted, now: () => at};
}
const object = (id, age = PHOTO_TTL_MS) => ({name: `communicationPhotos/a/${id}/0`,
  metadata: {generation: 'old-generation', timeCreated: new Date(at - age).toISOString()}});

test('cleans expired orphan/completed/failed photos but preserves recent and active uploads', async () => {
  const h = fixture([object('orphan'), object('completed'), object('failed'), object('active'),
    object('unknown-start'), object('abandoned'), object('recent', PHOTO_TTL_MS - 1),
    {name: 'journalImages/a/p/0', metadata: object('unused').metadata}], {
    'a/completed': {status: 'completed'}, 'a/failed': {status: 'failed'},
    'a/active': {status: 'processing', createdAt: {toMillis: () => at - 1000}},
    'a/unknown-start': {status: 'processing'},
    'a/abandoned': {status: 'processing', createdAt: {toMillis: () => at - PROCESSING_GRACE_MS}},
  });
  const result = await sweepCommunicationPhotos(h);
  assert.equal(result.deleted, 4);
  assert.deepEqual(h.deleted, ['orphan', 'completed', 'failed', 'abandoned'].map(id => object(id).name));
  assert.equal(result.skipped, 4);
});

test('replacement generations and missing objects do not fail the sweep or delete replacements', async () => {
  const h = fixture([object('replaced'), object('missing')]);
  h.bucket.file = (name, options) => ({delete: async () => {
    assert.equal(options.generation, 'old-generation');
    assert.equal(options.preconditionOpts.ifGenerationMatch, 'old-generation');
    throw Object.assign(new Error('changed'), {code: name.includes('replaced') ? 412 : 404});
  }});
  assert.deepEqual(await sweepCommunicationPhotos(h), {deleted: 0, skipped: 2, pageToken: null});
});

test('bounded page batches resume from a checkpoint and never advance on failure', async () => {
  let checkpoint = {pageToken: 'saved'};
  let fail = false;
  const requested = [];
  const db = {collection: name => {
    assert.equal(name, '_maintenance');
    return {doc: id => {
      assert.equal(id, 'communicationPhotoCleanup');
      return {get: async () => ({get: key => checkpoint[key]}), set: async value => { checkpoint = value; }};
    }};
  }};
  const bucket = {getFiles: async ({pageToken}) => {
    requested.push(pageToken);
    if (fail) throw new Error('storage unavailable');
    return [[], {pageToken: `page-${requested.length}`}];
  }};
  await runCommunicationPhotoCleanup({db, bucket});
  assert.equal(requested.length, 5);
  assert.equal(requested[0], 'saved');
  assert.equal(checkpoint.pageToken, 'page-5');
  fail = true;
  await assert.rejects(runCommunicationPhotoCleanup({db, bucket}), /storage unavailable/);
  assert.equal(requested.at(-1), 'page-5');
  assert.equal(checkpoint.pageToken, 'page-5');
});
