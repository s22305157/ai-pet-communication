const {PROCESSING_GRACE_MS, photoExpired} = require('./communication_photo_policy');

async function sweepCommunicationPhotos({db, bucket, now = Date.now, pageToken,
  maxPages = 5}) {
  let deleted = 0;
  let skipped = 0;
  for (let page = 0; page < maxPages; page++) {
    const [files, next] = await bucket.getFiles({prefix: 'communicationPhotos/',
      autoPaginate: false, maxResults: 100, ...(pageToken ? {pageToken} : {})});
    for (const file of files) {
      const match = /^communicationPhotos\/([^/]+)\/([^/]+)\/[0-2]$/.exec(file.name);
      const metadata = file.metadata;
      if (!match || !metadata?.generation || !photoExpired(metadata, now())) { skipped++; continue; }
      const operation = await db.collection('users').doc(match[1]).collection('aiRequests').doc(match[2]).get();
      const started = operation.get('createdAt')?.toMillis?.();
      if (operation.get('status') === 'processing' &&
          (!Number.isFinite(started) || started + PROCESSING_GRACE_MS > now())) { skipped++; continue; }
      try {
        // Pin the inspected generation so a replacement upload is never deleted.
        await bucket.file(file.name, {generation: metadata.generation,
          preconditionOpts: {ifGenerationMatch: metadata.generation}}).delete({ignoreNotFound: true});
        deleted++;
      } catch (error) {
        if (![404, 412].includes(Number(error.code))) throw error;
        skipped++;
      }
    }
    pageToken = next?.pageToken;
    if (!pageToken) break;
  }
  return {deleted, skipped, pageToken: pageToken || null};
}

async function runCommunicationPhotoCleanup({db, bucket, now = Date.now}) {
  const checkpoint = db.collection('_maintenance').doc('communicationPhotoCleanup');
  const previous = await checkpoint.get();
  const result = await sweepCommunicationPhotos({db, bucket, now, pageToken: previous.get('pageToken')});
  // Advance only after a successful page batch. Failures retry the same objects.
  await checkpoint.set({pageToken: result.pageToken});
  return {deleted: result.deleted, skipped: result.skipped};
}
module.exports = {sweepCommunicationPhotos, runCommunicationPhotoCleanup};
