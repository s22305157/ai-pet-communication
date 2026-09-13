const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {configuredCardIds} = require('../planet_cards');

test('every collectible card has exactly one server-owned award rule', () => {
  const catalog = JSON.parse(fs.readFileSync(path.join(__dirname, '../../content/planet_cards.json'), 'utf8'));
  assert.equal(new Set(configuredCardIds).size, configuredCardIds.length);
  assert.deepEqual(configuredCardIds, catalog.cards.map(card => card.id));
});
