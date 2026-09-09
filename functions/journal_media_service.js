const {Timestamp} = require('firebase-admin/firestore');
const {createHash, randomUUID} = require('node:crypto');
const P = require('./journal_policy');
const stamp = ms => Timestamp.fromMillis(ms);
module.exports = function register({handlers, db, bucket, now, normalize, access, livePet, mediaRef, petRef, mutate}) {
  handlers.beginJournalUpload = request => mutate(request, 'beginUpload', async ({tx, uid, d}) => {
    const pet = await livePet(tx, uid, d.petId);
    if (!['image/jpeg', 'image/png'].includes(d.contentType) || !Number.isInteger(d.bytes) || d.bytes < 1 || d.bytes > P.LIMITS.inputBytes) P.fail('invalid-argument', '照片格式或大小不符合限制');
    if ((pet.get('usedBytes') || 0) + (pet.get('reservedBytes') || 0) + P.LIMITS.imageBytes > P.LIMITS.bytes) P.fail('resource-exhausted', '圖片空間已滿');
    if ((pet.get('pendingUploads') || 0) >= 3) P.fail('resource-exhausted', '請先完成或取消現有照片上傳');
    const uploadDay = P.dayKey(now());
    const uploadCount = pet.get('uploadDay') === uploadDay ? pet.get('dailyUploads') || 0 : 0;
    if (uploadCount >= 60) P.fail('resource-exhausted', '已達今日照片上傳上限');
    const mediaId = randomUUID();
    tx.create(mediaRef(uid, mediaId), {petId: pet.id, status: 'pending', contentType: d.contentType,
      inputBytes: d.bytes, reserved: P.LIMITS.imageBytes, createdAt: stamp(now()), expiresAt: stamp(now() + 86400000), schemaVersion: 1});
    tx.update(pet.ref, {reservedBytes: (pet.get('reservedBytes') || 0) + P.LIMITS.imageBytes,
      pendingUploads: (pet.get('pendingUploads') || 0) + 1, uploadDay, dailyUploads: uploadCount + 1});
    return {mediaId, path: `journalUploads/${uid}/${mediaId}`};
  });

  handlers.finalizeJournalUpload = async request => {
    const uid = request.auth?.uid;
    if (!uid) P.fail('unauthenticated', '請先登入');
    const d = request.data || {};
    const mid = P.id(d.mediaId);
    const media = await db.runTransaction(async tx => {
      await access(tx, uid, true);
      const m = await tx.get(mediaRef(uid, mid));
      if (!m.exists || !['pending', 'ready'].includes(m.get('status'))) P.fail('not-found', '上傳不存在');
      await livePet(tx, uid, m.get('petId'));
      if (m.get('status') === 'pending' && P.millis(m.get('expiresAt')) <= now()) P.fail('failed-precondition', '上傳已過期');
      return m.data();
    });
    if (media.status === 'ready') return {mediaId: mid};
    const raw = bucket.file(`journalUploads/${uid}/${mid}`);
    let buffer;
    try {
      const [metadata] = await raw.getMetadata();
      if (Number(metadata.size) > P.LIMITS.inputBytes || Number(metadata.size) !== media.inputBytes) P.fail('invalid-argument', '照片大小不符合預留內容');
      const [bytes] = await raw.download({validation: 'crc32c'});
      buffer = await normalize(bytes);
    } catch (error) {
      if (error.code && typeof error.code === 'string') throw error;
      P.fail('failed-precondition', '照片尚未完整上傳');
    }
    // Unique objects avoid two concurrent finalizers deleting each other's output.
    const outputPath = `journalImages/${uid}/${mid}/${randomUUID()}.jpg`;
    await bucket.file(outputPath).save(buffer, {resumable: false, contentType: 'image/jpeg', metadata: {cacheControl: 'private, no-store'}});
    try {
      const result = await mutate(request, 'finalizeUpload', async ({tx, uid}) => {
        const m = await tx.get(mediaRef(uid, mid));
        if (!m.exists || !['pending', 'ready'].includes(m.get('status'))) P.fail('not-found', '上傳已取消');
        const pet = await livePet(tx, uid, m.get('petId'));
        if (m.get('status') === 'ready') return {mediaId: mid, path: m.get('path')};
        if (P.millis(m.get('expiresAt')) <= now()) P.fail('failed-precondition', '上傳已過期');
        tx.update(m.ref, {status: 'ready', path: outputPath, bytes: buffer.length, rawCleanupPending: true});
        tx.update(pet.ref, {reservedBytes: Math.max(0, pet.get('reservedBytes') - P.LIMITS.imageBytes), usedBytes: (pet.get('usedBytes') || 0) + buffer.length,
          pendingUploads: Math.max(0, (pet.get('pendingUploads') || 0) - 1)});
        return {mediaId: mid, path: outputPath};
      });
      if (result.path !== outputPath) await bucket.file(outputPath).delete({ignoreNotFound: true});
      await raw.delete({ignoreNotFound: true});
      return {mediaId: mid};
    } catch (error) {
      // Only remove our object if it was never committed. Cleanup handles other failures.
      const current = await mediaRef(uid, mid).get();
      if (current.get('path') !== outputPath) await bucket.file(outputPath).delete({ignoreNotFound: true});
      throw error;
    }
  };

  handlers.uploadJournalBytes = async request => {
    const uid = request.auth?.uid;
    if (!uid) P.fail('unauthenticated', '請先登入');
    const d = request.data || {};
    const mid = P.id(d.mediaId);
    if (typeof d.base64 !== 'string' || d.base64.length > Math.ceil(P.LIMITS.inputBytes / 3) * 4 ||
        !/^[A-Za-z0-9+/]+={0,2}$/.test(d.base64)) P.fail('invalid-argument', '圖片資料不正確');
    const bytes = Buffer.from(d.base64, 'base64');
    const sha = createHash('sha256').update(bytes).digest('hex');
    const check = async tx => {
      await access(tx, uid, true);
      const m = await tx.get(mediaRef(uid, mid));
      if (!m.exists || m.get('status') !== 'pending' || P.millis(m.get('expiresAt')) <= now()) P.fail('failed-precondition', '上傳已過期或已處理');
      await livePet(tx, uid, m.get('petId'));
      if (m.get('inputBytes') !== bytes.length || bytes.length > P.LIMITS.inputBytes) P.fail('invalid-argument', '圖片大小不正確');
      return m;
    };
    const m = await db.runTransaction(check);
    const file = bucket.file(`journalUploads/${uid}/${mid}`);
    try {
      await file.save(bytes, {resumable: false, preconditionOpts: {ifGenerationMatch: 0},
        contentType: m.get('contentType'), metadata: {cacheControl: 'private, no-store', metadata: {sha}}});
    } catch (error) {
      if (Number(error.code) !== 412) throw error;
      const [metadata] = await file.getMetadata();
      if (metadata.metadata?.sha !== sha) P.fail('already-exists', '此上傳已包含不同圖片');
    }
    try {
      await db.runTransaction(check);
      return {uploaded: true};
    } catch (error) { await file.delete({ignoreNotFound: true}); throw error; }
  };

  handlers.getJournalImage = async request => {
    const uid = request.auth?.uid;
    if (!uid) P.fail('unauthenticated', '請先登入');
    const mid = P.id(request.data?.mediaId);
    const check = async tx => {
      await access(tx, uid);
      const m = await tx.get(mediaRef(uid, mid));
      if (!m.exists || m.get('status') !== 'ready') P.fail('not-found', '照片已移除');
      if (!m.get('entryId') && P.millis(m.get('expiresAt')) <= now()) P.fail('not-found', '未儲存的照片已過期');
      await livePet(tx, uid, m.get('petId'));
      return m.get('path');
    };
    const path = await db.runTransaction(check);
    const [bytes] = await bucket.file(path).download();
    const current = await db.runTransaction(check);
    if (current !== path) P.fail('not-found', '照片已移除');
    return {base64: bytes.toString('base64')};
  };

  handlers.cancelJournalUpload = request => mutate(request, 'cancelUpload', async ({tx, uid, d}) => {
    const mid = P.id(d.mediaId);
    const m = await tx.get(mediaRef(uid, mid));
    if (!m.exists || m.get('status') === 'deleted') return {cancelled: true};
    if (m.get('entryId')) P.fail('failed-precondition', '這張照片已存入日記');
    const pet = await tx.get(petRef(uid, m.get('petId')));
    tx.update(m.ref, {status: 'deleted'});
    if (pet.exists) tx.update(pet.ref, {
      reservedBytes: Math.max(0, (pet.get('reservedBytes') || 0) - (m.get('status') === 'pending' ? P.LIMITS.imageBytes : 0)),
      pendingUploads: Math.max(0, (pet.get('pendingUploads') || 0) - (m.get('status') === 'pending' ? 1 : 0)),
      usedBytes: Math.max(0, (pet.get('usedBytes') || 0) - (m.get('status') === 'ready' ? m.get('bytes') : 0)),
    });
    tx.set(db.collection('_journalCleanup').doc(`${uid}_${mid}`), {uid, mediaId: mid, createdAt: stamp(now())});
    return {cancelled: true};
  }, {readOnly: true});


};
