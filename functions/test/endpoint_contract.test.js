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
