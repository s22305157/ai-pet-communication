const {createHash, randomUUID} = require('node:crypto');
const {Timestamp, FieldValue} = require('firebase-admin/firestore');
const P = require('./journal_policy');
const stamp = ms => Timestamp.fromMillis(ms);
const json = value => JSON.parse(JSON.stringify(value, (_, v) => v));

function createJournalService({db, bucket, now = Date.now, normalize = P.normalizeImage}) {
  const userRef = uid => db.collection('users').doc(uid);
  const participantRef = uid => db.collection('pilotParticipants').doc(uid);
  const petRef = (uid, petId) => userRef(uid).collection('journalPets').doc(P.id(petId));
  const mediaRef = (uid, mediaId) => userRef(uid).collection('journalMedia').doc(P.id(mediaId));

  async function access(tx, uid, write = false, activation = true) {
    const [user, deleted, participant, flags] = await Promise.all([
      tx.get(userRef(uid)), tx.get(db.collection('_deletedUsers').doc(uid)),
      tx.get(participantRef(uid)), tx.get(db.doc('pilotConfig/features'))]);
    if (!user.exists || deleted.exists) P.fail('permission-denied', '帳號已停用');
    const p = participant.data() || {};
    const config = flags.data() || {};
    const invited = p.status === 'invited' && P.millis(p.expiresAt) > now();
    if (write && (!invited || config.journalEnabled !== true || (activation && !p.activatedAt))) P.fail('permission-denied', '毛孩日記尚未開放或資格已到期');
    return {user: user.data(), p, config, invited};
  }

  async function livePet(tx, uid, petId) {
    const ref = petRef(uid, petId);
    const snapshot = await tx.get(ref);
    if (!snapshot.exists || snapshot.get('deletedAt')) P.fail('not-found', '日記毛孩不存在或已刪除');
    if (snapshot.get('linkedPetId')) {
      const tombstone = await tx.get(db.collection('petTombstones').doc(snapshot.get('linkedPetId')));
      if (tombstone.exists) P.fail('not-found', '原毛孩已刪除');
    }
    return snapshot;
  }

  async function mutate(request, name, handler, options = {}) {
    const uid = request.auth?.uid;
    if (!uid) P.fail('unauthenticated', '請先登入');
    const d = request.data || {};
    const opId = P.id(d.operationId);
    const hash = createHash('sha256').update(JSON.stringify({name, d})).digest('hex');
    const op = userRef(uid).collection('journalOperations').doc(opId);
    return db.runTransaction(async tx => {
      const a = await access(tx, uid, !options.readOnly, options.activation !== false);
      if (request.auth.token?.pilotAdmin === true) a.p = {...a.p, isAdmin: true};
      const existing = await tx.get(op);
      if (existing.exists) {
        if (existing.get('hash') !== hash) P.fail('already-exists', '請勿重用操作編號');
        return existing.get('result');
      }
      const rateRef = userRef(uid).collection('journalLimits').doc('operations');
      const rate = await tx.get(rateRef);
      const count = now() - (rate.get('windowMs') || 0) < 60000 ? rate.get('count') || 0 : 0;
      if (count >= 60) P.fail('resource-exhausted', '操作較頻繁，請稍後再試');
      const result = await handler({tx, uid, d, a});
      tx.set(rateRef, {windowMs: count ? rate.get('windowMs') : now(), count: count + 1});
      tx.create(op, {hash, result: json(result), createdAt: stamp(now()), schemaVersion: 1});
      return result;
    });
  }

  function event(tx, uid, a, kind, operationId) {
    if (!a.p.metricsConsent || a.p.isTest || a.p.isAdmin) return;
    tx.set(userRef(uid).collection('pilotEvents').doc(operationId), {
      type: kind, createdAt: stamp(now()), expiresAt: stamp(now() + 90 * 86400000), schemaVersion: 1});
  }

  const handlers = {};
  handlers.getPilotAccess = async request => {
    const uid = request.auth?.uid;
    if (!uid) P.fail('unauthenticated', '請先登入');
    return db.runTransaction(async tx => {
      const a = await access(tx, uid);
      return {invited: a.invited, enabled: a.config.journalEnabled === true,
        activated: !!a.p.activatedAt, expiresAtMs: P.millis(a.p.expiresAt),
        trialEndsAtMs: P.millis(a.p.trialEndsAt), metricsConsent: a.p.metricsConsent === true,
        limits: P.LIMITS};
    });
  };
  handlers.activatePilot = request => mutate(request, 'activate', async ({tx, uid, d, a}) => {
    if (d.consentVersion !== 'journal-m1-v1' || typeof d.metricsConsent !== 'boolean') P.fail('invalid-argument', '請閱讀並同意日記說明');
    const fields = {consentVersion: d.consentVersion, metricsConsent: d.metricsConsent, schemaVersion: 1};
    if (!a.p.activatedAt) Object.assign(fields, {activatedAt: stamp(now()), trialEndsAt: stamp(now() + 28 * 86400000)});
    tx.update(participantRef(uid), fields);
    if (!a.p.activatedAt) event(tx, uid, {...a, p: {...a.p, metricsConsent: d.metricsConsent}}, 'activated', d.operationId);
    return {activated: true};
  }, {activation: false});

  handlers.createJournalPet = request => mutate(request, 'createPet', async ({tx, uid, d, a}) => {
    const name = P.text(d.name, 80, true);
    const species = P.text(d.species, 80, true);
    if (!P.FOCUSES.includes(d.focus)) P.fail('invalid-argument', '請選擇目前關注的情境');
    const arrivedAt = d.arrivedAtMs == null ? null : stamp(P.time(d.arrivedAtMs, now()));
    const existing = await tx.get(userRef(uid).collection('journalPets').limit(2));
    if (!existing.empty) P.fail('resource-exhausted', '第一版每人提供一份日記毛孩資料；刪除清理可能需要一段時間');
    let linkedPetId = null;
    if (d.linkedPetId) {
      linkedPetId = P.id(d.linkedPetId);
      const [pet, tombstone] = await Promise.all([tx.get(db.doc(`pets/${linkedPetId}`)), tx.get(db.doc(`petTombstones/${linkedPetId}`))]);
      if (!pet.exists || pet.get('owner_id') !== uid || tombstone.exists) P.fail('permission-denied', '無法連結此毛孩');
    }
    const ref = userRef(uid).collection('journalPets').doc();
    tx.create(ref, {name, species, focus: d.focus, arrivedAt, linkedPetId,
      entryCount: 0, usedBytes: 0, reservedBytes: 0, pendingUploads: 0, revision: 1, createdAt: stamp(now()), schemaVersion: 1});
    // Serialize concurrent creates against the participant document, even on empty queries.
    tx.update(participantRef(uid), {journalPetId: ref.id});
    event(tx, uid, a, 'pet_created', d.operationId);
    return {petId: ref.id};
  });

  handlers.upsertJournalEntry = request => mutate(request, 'saveEntry', async ({tx, uid, d, a}) => {
    const input = P.entryInput(d, now());
    const pet = await livePet(tx, uid, d.petId);
    const ref = pet.ref.collection('entries').doc(P.id(d.entryId));
    const current = await tx.get(ref);
    if ((current.get('revision') || 0) !== d.expectedRevision || current.get('deletedAt')) P.fail('aborted', '資料版本已變更，請重新載入；草稿已保留');
    const allIds = [...new Set([...(current.get('mediaIds') || []), ...input.mediaIds])];
    const media = await Promise.all(allIds.map(mid => tx.get(mediaRef(uid, mid))));
    for (const m of media.filter(m => input.mediaIds.includes(m.id))) {
      if (!m.exists || m.get('status') !== 'ready' || m.get('petId') !== d.petId ||
          (m.get('entryId') && m.get('entryId') !== ref.id)) P.fail('invalid-argument', '照片未完成上傳或已用於其他日記');
      if (!m.get('entryId') && P.millis(m.get('expiresAt')) <= now()) P.fail('failed-precondition', '未儲存的照片已過期，請移除後重新上傳');
    }
    const day = P.dayKey(now());
    const todayCount = pet.get('entryDay') === day ? pet.get('dailyEntries') || 0 : 0;
    if (!current.exists && (pet.get('entryCount') >= P.LIMITS.entries || todayCount >= P.LIMITS.dailyEntries)) P.fail('resource-exhausted', '已達日記數量上限，草稿已保留');
    const removed = media.filter(m => !input.mediaIds.includes(m.id) && m.exists && m.get('status') === 'ready');
    const released = removed.reduce((n, m) => n + m.get('bytes'), 0);
    const {occurredAtMs, ...content} = input;
    tx.set(ref, {...content, occurredAt: stamp(occurredAtMs), revision: d.expectedRevision + 1,
      createdAt: current.get('createdAt') || stamp(now()), updatedAt: stamp(now()), schemaVersion: 1});
    tx.update(pet.ref, {entryCount: (pet.get('entryCount') || 0) + (current.exists ? 0 : 1),
      revision: pet.get('revision') + 1, usedBytes: Math.max(0, (pet.get('usedBytes') || 0) - released),
      ...(!current.exists ? {entryDay: day, dailyEntries: todayCount + 1} : {})});
    for (const m of media) {
      if (input.mediaIds.includes(m.id)) tx.update(m.ref, {entryId: ref.id, expiresAt: FieldValue.delete()});
      else if (m.exists) {
        tx.update(m.ref, {status: 'deleted'});
        tx.set(db.collection('_journalCleanup').doc(`${uid}_${m.id}`), {uid, mediaId: m.id, createdAt: stamp(now())});
      }
    }
    event(tx, uid, a, current.exists ? 'entry_updated' : 'entry_created', d.operationId);
    return {entryId: ref.id, revision: d.expectedRevision + 1};
  });

  handlers.deleteJournalEntry = request => mutate(request, 'deleteEntry', async ({tx, uid, d}) => {
    const pet = await livePet(tx, uid, d.petId);
    const ref = pet.ref.collection('entries').doc(P.id(d.entryId));
    const entry = await tx.get(ref);
    if (!entry.exists || entry.get('deletedAt')) return {deleted: true};
    if (entry.get('revision') !== d.expectedRevision) P.fail('aborted', '資料版本已變更，請重新載入');
    const media = await Promise.all((entry.get('mediaIds') || []).map(mid => tx.get(mediaRef(uid, mid))));
    const bytes = media.reduce((n, m) => n + (m.get('status') === 'ready' ? m.get('bytes') || 0 : 0), 0);
    // Tombstones prevent replayed offline creates from resurrecting a deleted entry.
    tx.set(ref, {deletedAt: stamp(now()), revision: entry.get('revision') + 1, schemaVersion: 1});
    tx.update(pet.ref, {entryCount: Math.max(0, pet.get('entryCount') - 1), revision: pet.get('revision') + 1,
      usedBytes: Math.max(0, (pet.get('usedBytes') || 0) - bytes)});
    for (const m of media.filter(m => m.exists)) {
      tx.update(m.ref, {status: 'deleted'});
      tx.set(db.collection('_journalCleanup').doc(`${uid}_${m.id}`), {uid, mediaId: m.id, createdAt: stamp(now())});
    }
    return {deleted: true};
  }, {readOnly: true});

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

  handlers.listJournalEntries = async request => {
    const uid = request.auth?.uid;
    if (!uid) P.fail('unauthenticated', '請先登入');
    const d = request.data || {};
    return db.runTransaction(async tx => {
      await access(tx, uid);
      const pet = await livePet(tx, uid, d.petId);
      let q = pet.ref.collection('entries').orderBy('occurredAt', 'desc').orderBy('__name__', 'desc');
      if (d.context) {
        if (!P.CONTEXTS.includes(d.context)) P.fail('invalid-argument', '情境不正確');
        q = q.where('context', '==', d.context);
      }
      if (d.fromMs != null) q = q.where('occurredAt', '>=', stamp(P.time(d.fromMs, now())));
      if (d.toMs != null) q = q.where('occurredAt', '<=', stamp(P.time(d.toMs, now())));
      if (d.cursor) q = q.startAfter(stamp(P.time(d.cursor.time, now())), P.id(d.cursor.id));
      const rows = await tx.get(q.limit(21));
      const items = rows.docs.slice(0, 20).map(s => ({id: s.id, ...s.data(), occurredAtMs: P.millis(s.get('occurredAt')),
        createdAtMs: P.millis(s.get('createdAt')), occurredAt: undefined, createdAt: undefined, updatedAt: undefined}));
      const last = items.at(-1);
      return {items: JSON.parse(JSON.stringify(items)), cursor: rows.size > 20 && last ? {time: last.occurredAtMs, id: last.id} : null};
    });
  };

  handlers.getJournalHome = async request => {
    const uid = request.auth?.uid;
    if (!uid) P.fail('unauthenticated', '請先登入');
    return db.runTransaction(async tx => {
      await access(tx, uid);
      const pets = await tx.get(userRef(uid).collection('journalPets').limit(1));
      if (pets.empty || pets.docs[0].get('deletedAt')) return {pet: null};
      const pet = await livePet(tx, uid, pets.docs[0].id);
      const today = P.dayKey(now());
      const local = new Date(`${today}T00:00:00+08:00`);
      const weekday = new Date(now() + 8 * 3600000).getUTCDay();
      const monday = local.getTime() - ((weekday + 6) % 7) * 86400000;
      const entries = await tx.get(pet.ref.collection('entries').where('occurredAt', '>=', stamp(monday)).limit(300));
      return {pet: {id: pet.id, name: pet.get('name'), species: pet.get('species'), focus: pet.get('focus'), entryCount: pet.get('entryCount'),
        usedBytes: pet.get('usedBytes'), reservedBytes: pet.get('reservedBytes')},
      weekDays: new Set(entries.docs.map(s => P.dayKey(P.millis(s.get('occurredAt'))))).size};
    });
  };

  handlers.exportJournal = async request => {
    const uid = request.auth?.uid;
    if (!uid) P.fail('unauthenticated', '請先登入');
    return db.runTransaction(async tx => {
      await access(tx, uid);
      const pet = await livePet(tx, uid, request.data?.petId);
      const entries = await tx.get(pet.ref.collection('entries').orderBy('occurredAt').limit(300));
      return {schemaVersion: 1, name: pet.get('name'), entries: entries.docs.map(s => ({id: s.id,
        observation: s.get('observation'), action: s.get('action'), outcome: s.get('outcome'), context: s.get('context'),
        occurredAt: new Date(P.millis(s.get('occurredAt'))).toISOString(), mediaIds: s.get('mediaIds')}))};
    });
  };

  handlers.adminSetPilotParticipant = async request => {
    if (!request.auth?.uid || request.auth.token.pilotAdmin !== true) P.fail('permission-denied', '需要試營運管理權限');
    const d = request.data || {};
    const uid = P.id(d.uid);
    const op = P.id(d.operationId);
    if (!['invited', 'disabled'].includes(d.status) || !Number.isSafeInteger(d.expiresAtMs) || d.expiresAtMs <= now()) P.fail('invalid-argument', '資格或期限不正確');
    return db.runTransaction(async tx => {
      await access(tx, request.auth.uid);
      await access(tx, uid);
      const ref = db.collection('_pilotAdminAudit').doc(op);
      const previous = await tx.get(ref);
      const details = {uid, status: d.status, expiresAtMs: d.expiresAtMs, isTest: d.isTest === true};
      if (previous.exists) {
        if (previous.get('actor') !== request.auth.uid || JSON.stringify(previous.get('details')) !== JSON.stringify(details)) P.fail('already-exists', '操作編號已使用');
        return {saved: true};
      }
      tx.set(participantRef(uid), {status: d.status, expiresAt: stamp(d.expiresAtMs), isTest: d.isTest === true, schemaVersion: 1}, {merge: true});
      tx.create(ref, {actor: request.auth.uid, details, createdAt: stamp(now())});
      return {saved: true};
    });
  };

  async function cleanupMedia(uid, mid) {
    const mref = mediaRef(uid, mid);
    await db.runTransaction(async tx => {
      const m = await tx.get(mref);
      if (!m.exists || m.get('status') === 'deleted') return;
      if (m.get('entryId') || P.millis(m.get('expiresAt')) > now()) return;
      const p = await tx.get(petRef(uid, m.get('petId')));
      tx.update(mref, {status: 'deleted'});
      if (p.exists) tx.update(p.ref, {reservedBytes: Math.max(0, (p.get('reservedBytes') || 0) - (m.get('status') === 'pending' ? P.LIMITS.imageBytes : 0)),
        pendingUploads: Math.max(0, (p.get('pendingUploads') || 0) - (m.get('status') === 'pending' ? 1 : 0)),
        usedBytes: Math.max(0, (p.get('usedBytes') || 0) - (m.get('status') === 'ready' ? m.get('bytes') : 0))});
    });
    const m = await mref.get();
    if (m.exists && m.get('status') !== 'deleted') return;
    await bucket.file(`journalUploads/${uid}/${mid}`).delete({ignoreNotFound: true});
    await bucket.deleteFiles({prefix: `journalImages/${uid}/${mid}/`});
    if (m.exists) await mref.update({expiresAt: FieldValue.delete()});
    await db.collection('_journalCleanup').doc(`${uid}_${mid}`).delete();
  }

  async function markPetDeleted(uid, petId) {
    const ref = petRef(uid, petId);
    await db.runTransaction(async tx => {
      const pet = await tx.get(ref);
      if (pet.exists) tx.update(ref, {deletedAt: stamp(now())});
      tx.set(db.collection('_journalPetCleanup').doc(`${uid}_${petId}`), {uid, petId, createdAt: stamp(now())});
    });
  }
  async function cleanupPet(uid, petId) {
    const media = await userRef(uid).collection('journalMedia').where('petId', '==', petId).get();
    for (const m of media.docs) {
      await m.ref.update({status: 'deleted'});
      await cleanupMedia(uid, m.id);
      await m.ref.delete();
    }
    await db.recursiveDelete(petRef(uid, petId));
    await db.collection('_journalPetCleanup').doc(`${uid}_${petId}`).delete();
  }
  handlers.deleteJournalPet = request => mutate(request, 'deletePet', async ({tx, uid, d}) => {
    const ref = petRef(uid, d.petId);
    const pet = await tx.get(ref);
    if (!pet.exists) return {deleted: true};
    tx.update(ref, {deletedAt: stamp(now())});
    tx.set(db.collection('_journalPetCleanup').doc(`${uid}_${d.petId}`), {uid, petId: d.petId, createdAt: stamp(now())});
    return {deleted: true};
  }, {readOnly: true});

  async function sweep() {
    let failures = 0;
    const attempt = async task => { try { await task(); } catch (_) { failures++; } };
    const ready = await db.collectionGroup('journalMedia').where('rawCleanupPending', '==', true).limit(500).get();
    for (const m of ready.docs) {
      await attempt(async () => {
        await bucket.file(`journalUploads/${m.ref.parent.parent.id}/${m.id}`).delete({ignoreNotFound: true});
        await m.ref.update({rawCleanupPending: false});
      });
    }
    const media = await db.collectionGroup('journalMedia').where('expiresAt', '<=', stamp(now())).limit(500).get();
    for (const m of media.docs) if (!m.get('entryId')) await attempt(() => cleanupMedia(m.ref.parent.parent.id, m.id));
    const jobs = await db.collection('_journalCleanup').limit(500).get();
    for (const j of jobs.docs) await attempt(() => cleanupMedia(j.get('uid'), j.get('mediaId')));
    const pets = await db.collection('_journalPetCleanup').limit(100).get();
    for (const j of pets.docs) await attempt(() => cleanupPet(j.get('uid'), j.get('petId')));
    const events = await db.collectionGroup('pilotEvents').where('expiresAt', '<=', stamp(now())).limit(500).get();
    for (const e of events.docs) await attempt(() => e.ref.delete());
    if (failures) throw new Error(`Journal cleanup requires retry (${failures} jobs)`);
  }
  return {handlers, sweep, markPetDeleted, cleanupPet};
}
module.exports = {createJournalService};
