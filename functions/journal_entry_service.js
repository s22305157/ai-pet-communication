const {Timestamp, FieldValue} = require('firebase-admin/firestore');
const P = require('./journal_policy');
const stamp = ms => Timestamp.fromMillis(ms);
module.exports = function register({handlers, db, now, access, livePet, mediaRef, mutate, event}) {
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

};
