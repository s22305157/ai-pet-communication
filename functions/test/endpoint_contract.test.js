const test = require('node:test');
const assert = require('node:assert/strict');
const {endpointNames, assertEndpointHandlers} = require('../endpoints');
const {createJournalService} = require('../journal_service');

test('every registered feature endpoint has an implemented handler', () => {
  const {handlers} = createJournalService({db: {}, bucket: {}});
  assertEndpointHandlers(handlers);
  assert.equal(endpointNames.length, Object.keys(handlers).length);
  assert.throws(() => assertEndpointHandlers({...handlers, getWeeklyReview: null}), /getWeeklyReview/);
});

test('lazy feature handlers reject anonymous callers before any data access', async () => {
  for (const name of endpointNames) {
    const db = {runTransaction: async callback => callback({get: () => assert.fail('anonymous storage access')})};
    const {handlers} = createJournalService({db, bucket: {}});
    await assert.rejects(async () => handlers[name]({data: {}}),
        error => ['unauthenticated', 'permission-denied'].includes(error.code), name);
  }
});
