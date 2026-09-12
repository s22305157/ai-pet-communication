const {test} = require('node:test');
const assert = require('node:assert/strict');
const {summarize, DAY} = require('../pilot_metrics');
const now = Date.parse('2026-09-30T12:00:00+08:00');
const person = (id, days = 30, more = {}) => ({id, joined: now - days * DAY, metricsConsent: true, ...more});
const event = (uid, type, at, subject) => ({uid, type, at, subject});
test('activation and week 4 use completed cohorts, 48-hour exclusive end and Taipei dates', () => {
  const a = person('a'), b = person('b'), c = person('c', 1);
  const r = summarize([a, b, c], [
    event('a', 'entry_created', a.joined + 2 * DAY - 1), event('b', 'entry_created', b.joined + 2 * DAY),
    event('a', 'entry_created', a.joined + 21 * DAY), event('a', 'review_viewed', a.joined + 22 * DAY),
    event('b', 'entry_created', b.joined + 21 * DAY), event('b', 'review_viewed', b.joined + 21 * DAY + 10),
    event('b', 'review_viewed', b.joined + 28 * DAY),
  ], now);
  assert.deepEqual(r.activation, {numerator: 1, denominator: 2, pending: 1, rate: .5});
  assert.deepEqual(r.retention, {numerator: 1, denominator: 2, pending: 1, rate: .5});
});
test('seven-day ratios exclude self responses, admins, tests, nonconsent, wrong subject and late responses', () => {
  const people = [person('a'), person('b'), person('admin', 30, {isAdmin: true}), person('test', 30, {isTest: true}), person('out', 30, {metricsConsent: false})];
  const at = now - 8 * DAY;
  const rows = ['one', 'self', 'admin', 'test', 'out', 'late'].map(s => event('a', 'post_created', at, s));
  rows.push(event('b', 'comment_created', at + DAY, 'one'), event('a', 'encouragement_created', at + DAY, 'self'),
    event('admin', 'comment_created', at, 'admin'), event('test', 'comment_created', at, 'test'), event('out', 'comment_created', at, 'out'),
    event('b', 'comment_created', at + 7 * DAY, 'late'), event('a', 'post_created', now, 'pending'),
    event('a', 'review_generated', at, 'review'), event('b', 'review_viewed', at + DAY, 'review'),
    event('a', 'review_viewed', at + DAY, 'other'), event('a', 'review_viewed', at + DAY, 'review'));
  const r = summarize(people, rows, now);
  assert.deepEqual(r.communityResponses, {numerator: 1, denominator: 6, pending: 1, rate: 1/6});
  assert.equal(r.reviewViews.rate, 1); assert.equal(r.measuredParticipants, 2);
});
test('price views count people once and reflect current cancellation; summaries contain no identifiers', () => {
  const r = summarize([person('private-a', 30, {interested: false}), person('private-b', 30, {interested: true})],
    [event('private-a', 'price_viewed', now - DAY), event('private-a', 'price_viewed', now), event('private-b', 'price_viewed', now)], now);
  assert.deepEqual(r.upgradeInterest, {numerator: 1, denominator: 2, pending: 0, rate: .5});
  assert.ok(!JSON.stringify(r).includes('private-'));
});
test('missing, expired and partial consent histories are not invented as successes or failures', () => {
  const r = summarize([person('old', 100), person('late', 30, {measuredFrom: now - DAY})],
    [event('late', 'post_created', now), event('old', 'price_viewed', now - 91 * DAY)], now);
  assert.equal(r.activation.rate, null); assert.equal(r.retention.rate, null);
  assert.equal(r.incompleteCohorts, 1); assert.equal(r.legacyUnlinkedEvents, 1);
  assert.equal(r.communityResponses.rate, null); assert.equal(r.upgradeInterest.rate, null);
});
test('two activity instants across Taipei midnight count as distinct dates', () => {
  const p = person('a');
  const midnight = Date.parse('2026-09-22T00:00:00+08:00');
  const r = summarize([p], [event('a', 'entry_created', midnight - 1), event('a', 'review_viewed', midnight)], now);
  assert.equal(r.retention.rate, 1);
});
