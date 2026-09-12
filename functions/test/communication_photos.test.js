const test = require('node:test');
const assert = require('node:assert/strict');
const {Readable} = require('node:stream');
const sharp = require('sharp');
const {validateMedia, loadPhotos, MAX_BYTES} = require('../communication_photos');
const media = {photos: ['communicationPhotos/u/request-000000001/0']};
function load(bytes, metadata = {}) {
  return loadPhotos({media, uid: 'u', requestId: 'request-000000001', bucket: {file: (_, options) => ({
    getMetadata: async () => [{size: bytes.length, contentType: 'image/png', generation: '123', ...metadata}],
    createReadStream: () => { assert.equal(options.generation, '123'); return Readable.from([bytes]); },
  })}});
}
test('media contract enforces counts, uniqueness and disallows inline media or external URLs', () => {
  assert.equal(validateMedia(null), null);
  for (const invalid of [{photos: []}, {photos: ['a', 'b', 'c', 'd']}, {photos: ['a', 'a']},
    {photos: ['a'], imageUrl: 'https://example.com'}, {imageBase64: 'abc'}, []]) {
    assert.throws(() => validateMedia(invalid), {code: 'invalid-argument'});
  }
});
test('valid images are decoded, normalized and support the exact 10 MB boundary', async () => {
  const png = await sharp({create: {width: 2, height: 3, channels: 3, background: '#abcdef'}}).png().toBuffer();
  const bytes = Buffer.concat([png, Buffer.alloc(MAX_BYTES - png.length)]);
  const images = await load(bytes);
  assert.equal(images.length, 1);
  assert.match(images[0], /^data:image\/jpeg;base64,/);
  const info = await sharp(Buffer.from(images[0].split(',')[1], 'base64')).metadata();
  assert.equal(info.width, 2); assert.equal(info.height, 3);
});
test('oversized, forged content types and undecodable images are rejected', async () => {
  for (const [bytes, metadata] of [[Buffer.from('fake'), {}], [Buffer.from('x'), {size: MAX_BYTES + 1}],
    [Buffer.from('x'), {contentType: 'text/html'}], [Buffer.alloc(MAX_BYTES + 1), {size: 1}]]) {
    await assert.rejects(load(bytes, metadata), {code: 'invalid-argument'});
  }
});
