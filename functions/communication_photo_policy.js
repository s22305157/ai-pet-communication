const PHOTO_TTL_MS = 24 * 60 * 60 * 1000;
// The callable timeout is 90 seconds; leave a conservative margin for cleanup.
const PROCESSING_GRACE_MS = 10 * 60 * 1000;
const photoCreatedAt = metadata => Date.parse(metadata.timeCreated);
const photoExpired = (metadata, now) => Number.isFinite(photoCreatedAt(metadata)) &&
  photoCreatedAt(metadata) + PHOTO_TTL_MS <= now;
module.exports = {PHOTO_TTL_MS, PROCESSING_GRACE_MS, photoCreatedAt, photoExpired};
