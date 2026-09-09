const {test} = require('node:test');
const assert = require('node:assert/strict');
const sharp = require('sharp');
const P = require('../journal_policy');
const input = {observation: '今天走進外出籠', action: '', outcome: '', context: '外出籠', mediaIds: [], expectedRevision: 0, occurredAtMs: 1000};
test('journal validates time, content, revision and media independently of communication rules', () => {
  assert.equal(P.entryInput(input, 2000).observation, input.observation);
  for (const patch of [{occurredAtMs: 3000}, {observation: 'a'.repeat(2001)}, {context: 'system'}, {expectedRevision: -1},
    {observation: ''}, {mediaIds: ['a', 'a']}, {mediaIds: ['../../a']}]) {
    assert.throws(() => P.entryInput({...input, ...patch}, 2000));
  }
  assert.equal(P.entryInput({...input, observation: '', mediaIds: ['photo']}, 2000).mediaIds.length, 1);
  assert.equal(P.dayKey(Date.parse('2026-09-06T16:00:00Z')), '2026-09-07');
});
test('normalization decodes real pixels, bounds dimensions, strips EXIF and rejects unsupported formats', async () => {
  const original = await sharp({create: {width: 2400, height: 1800, channels: 3, background: '#8ba784'}})
    .withMetadata({exif: {IFD0: {Artist: 'private owner'}}}).png().toBuffer();
  const output = await P.normalizeImage(original);
  const meta = await sharp(output).metadata();
  assert.equal(meta.format, 'jpeg');
  assert.ok(meta.width <= 1600 && meta.height <= 1600);
  assert.equal(meta.exif, undefined);
  assert.ok(output.length <= P.LIMITS.imageBytes);
  for (const buffer of [Buffer.from('<svg></svg>'), Buffer.from('not a photo'), Buffer.alloc(P.LIMITS.inputBytes + 1),
    await sharp(original).webp().toBuffer()]) await assert.rejects(P.normalizeImage(buffer));
});
