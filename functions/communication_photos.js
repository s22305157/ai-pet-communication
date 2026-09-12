const {HttpsError} = require('firebase-functions/v2/https');
const sharp = require('sharp');
const MAX_BYTES = 10 * 1024 * 1024;

function validateMedia(media) {
  if (media == null) return null;
  if (typeof media !== 'object' || Array.isArray(media) ||
      Object.keys(media).length !== 1 || !Array.isArray(media.photos) ||
      media.photos.length < 1 || media.photos.length > 3 ||
      media.photos.some(path => typeof path !== 'string' || path.length > 300) ||
      new Set(media.photos).size !== media.photos.length) {
    throw new HttpsError('invalid-argument', '照片限 1 至 3 張');
  }
  return {photos: [...media.photos]};
}

function validatePaths(media, uid, requestId) {
  const prefix = `communicationPhotos/${uid}/${requestId}/`;
  if (media?.photos.some(path => !path.startsWith(prefix) ||
      !/^[0-2]$/.test(path.slice(prefix.length)))) {
    throw new HttpsError('permission-denied', '無法存取此照片');
  }
}

async function loadPhotos({media, uid, requestId, bucket}) {
  validatePaths(media, uid, requestId);
  const images = [];
  for (const path of media?.photos || []) {
    const file = bucket.file(path);
    const [metadata] = await file.getMetadata();
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(metadata.contentType) ||
        !Number.isFinite(Number(metadata.size)) || Number(metadata.size) <= 0 || Number(metadata.size) > MAX_BYTES) {
      throw new HttpsError('invalid-argument', '照片須為 JPG、PNG 或 WebP，每張上限 10 MB');
    }
    // Pin the checked generation; limit the download even if metadata is wrong.
    const pinned = bucket.file(path, {generation: metadata.generation});
    const chunks = [];
    let size = 0;
    for await (const chunk of pinned.createReadStream()) {
      size += chunk.length;
      if (size > MAX_BYTES) throw new HttpsError('invalid-argument', '照片超過 10 MB');
      chunks.push(chunk);
    }
    try {
      const bytes = Buffer.concat(chunks);
      const info = await sharp(bytes, {limitInputPixels: 40000000}).metadata();
      if (!['jpeg', 'png', 'webp'].includes(info.format) || (info.pages || 1) > 1) throw new Error('Invalid image');
      // Decode, orient and strip metadata before passing images to the model.
      const normalized = await sharp(bytes, {limitInputPixels: 40000000}).rotate()
        .resize({width: 2048, height: 2048, fit: 'inside', withoutEnlargement: true}).jpeg({quality: 85}).toBuffer();
      images.push(`data:image/jpeg;base64,${normalized.toString('base64')}`);
    } catch (_) {
      throw new HttpsError('invalid-argument', '照片無法讀取，請改用一般 JPG、PNG 或 WebP 照片');
    }
  }
  return images;
}

module.exports = {validateMedia, validatePaths, loadPhotos, MAX_BYTES};
