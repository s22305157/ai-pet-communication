const test = require('node:test');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const path = require('node:path');

test('journal and review handlers resolve independently of other feature factories', () => {
  const result = spawnSync(process.execPath, ['-e', `
    const assert = require('node:assert/strict');
    const {createJournalService} = require('./journal_service');
    const service = createJournalService({db: {}, bucket: {}});
    const loaded = name => Boolean(require.cache[require.resolve('./' + name)]);
    assert.equal(loaded('community_service'), false);
    assert.equal(loaded('weekly_review_service'), false);
    assert.equal(typeof service.handlers.upsertJournalEntry, 'function');
    assert.equal(loaded('community_service'), false);
    assert.equal(loaded('pilot_metrics_service'), false);
    assert.equal(loaded('weekly_review_service'), false);
    assert.equal(typeof service.handlers.getWeeklyReview, 'function');
    assert.equal(loaded('weekly_review_service'), true);
    assert.equal(loaded('community_service'), false);
    assert.equal(loaded('pilot_metrics_service'), false);
    assert.equal(service.reviews, service.reviews);
    assert.equal(typeof service.handlers.deleteJournalPet, 'function');
    assert.equal(loaded('community_service'), false);
  `], {cwd: path.resolve(__dirname, '..'), encoding: 'utf8'});
  assert.equal(result.status, 0, result.stderr);
});

test('text-only and invalid photo paths do not load the native image library', () => {
  const result = spawnSync(process.execPath, ['-e', `
    const assert = require('node:assert/strict');
    const {loadPhotos, validatePaths} = require('./communication_photos');
    assert.equal(require.cache[require.resolve('sharp')], undefined);
    assert.throws(() => validatePaths({photos: ['foreign/path']}, 'a', 'id'));
    loadPhotos({media: null, uid: 'a', requestId: 'id'}).then(result => {
      assert.deepEqual(result, []);
      assert.equal(require.cache[require.resolve('sharp')], undefined);
    });
  `], {cwd: path.resolve(__dirname, '..'), encoding: 'utf8'});
  assert.equal(result.status, 0, result.stderr);
});
