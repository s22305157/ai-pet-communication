const {Timestamp, FieldValue} = require('firebase-admin/firestore');
module.exports = function createCleanup({db, bucket, now, posts, users, liveSource}) {
  async function removePost(id, uid) {
    const ref = posts(id);
    await db.runTransaction(async tx => {
      const p = await tx.get(ref);
      if (p.exists) tx.update(ref, {status: 'withdrawn', text: '', mediaIds: [], copies: FieldValue.delete()});
      tx.set(db.collection('_communityCleanup').doc(id), {postId: id, uid, nextAt: Timestamp.fromMillis(now())});
    });
    await bucket.deleteFiles({prefix: `communityImages/${uid}/${id}/`});
    for (const name of ['comments', 'encouragements']) await db.recursiveDelete(ref.collection(name));
    const notes = await db.collectionGroup('pilotNotifications').where('postId', '==', id).get();
    for (const n of notes.docs) await n.ref.delete();
    await db.collection('_communityCleanup').doc(id).delete();
  }
  async function cleanupSource(uid, petId, entryId = null) {
    let query = db.collection('communityPosts').where('authorId', '==', uid).where('petId', '==', petId);
    if (entryId) query = query.where('entryId', '==', entryId);
    const rows = await query.get();
    for (const post of rows.docs) {
      await removePost(post.id, uid);
      // Keep a minimal tombstone so an old operation cannot resurrect a share.
      await post.ref.set({authorId: uid, petId, entryId: post.get('entryId'), status: 'withdrawn', revision: (post.get('revision') || 0) + 1});
    }
  }
  async function cleanupAccount(uid) {
    const authored = await db.collection('communityPosts').where('authorId', '==', uid).get();
    for (const p of authored.docs) { await removePost(p.id, uid); await db.recursiveDelete(p.ref); }
    for (const name of ['comments', 'encouragements']) {
      const rows = await db.collectionGroup(name).where('authorId', '==', uid).get();
      for (const s of rows.docs) {
        await db.runTransaction(async tx => {
          const current = await tx.get(s.ref), parent = await tx.get(s.ref.parent.parent);
          if (!current.exists) return;
          const field = name === 'comments' ? 'commentCount' : 'encouragementCount';
          if (parent.exists && (name !== 'comments' || current.get('status') === 'published')) tx.update(parent.ref, {[field]: Math.max(0, (parent.get(field) || 0) - 1)});
          tx.delete(s.ref);
        });
      }
    }
    const blocks = await db.collectionGroup('communityBlocks').where('targetId', '==', uid).get();
    for (const b of blocks.docs) await b.ref.delete();
    for (const field of ['reporterId', 'authorId']) {
      const reports = await db.collection('communityReports').where(field, '==', uid).get();
      for (const r of reports.docs) await r.ref.delete();
    }
    const individual = await db.collectionGroup('pilotNotifications').where('actorId', '==', uid).get();
    for (const n of individual.docs) await n.ref.delete();
    const merged = await db.collectionGroup('pilotNotifications').where('actorIds', 'array-contains', uid).get();
    for (const n of merged.docs) await db.runTransaction(async tx => {
      const current = await tx.get(n.ref);
      if (!current.exists) return;
      const actorIds = (current.get('actorIds') || []).filter(id => id !== uid);
      if (actorIds.length) tx.update(n.ref, {actorIds}); else tx.delete(n.ref);
    });
    const jobs = await db.collection('_weeklyReviewJobs').where('uid', '==', uid).get();
    for (const j of jobs.docs) await j.ref.delete();
    await bucket.deleteFiles({prefix: `communityImages/${uid}/`});
    await db.recursiveDelete(users(uid).collection('pilotNotifications'));
  }
  async function sweep() {
    let failures = 0;
    const attempt = async fn => { try { await fn(); } catch (_) { failures++; } };
    const sourceJobs = await db.collection('_communitySourceCleanup').limit(100).get();
    for (const j of sourceJobs.docs) await attempt(async () => {
      await cleanupSource(j.get('uid'), j.get('petId'), j.get('entryId') || null); await j.ref.delete();
    });
    const jobs = await db.collection('_communityCleanup').where('nextAt', '<=', Timestamp.fromMillis(now())).limit(100).get();
    for (const j of jobs.docs) await attempt(() => removePost(j.get('postId'), j.get('uid')));
    // A source tombstone revokes reads immediately, even before any scheduled cleanup.
    let cursor;
    do {
      let q = db.collection('communityPosts').orderBy('__name__').limit(100);
      if (cursor) q = q.startAfter(cursor);
      const rows = await q.get(); cursor = rows.size === 100 ? rows.docs.at(-1) : null;
      for (const post of rows.docs) {
        if (!['published', 'hidden'].includes(post.get('status'))) continue;
        await attempt(async () => {
          try { await db.runTransaction(tx => liveSource(tx, post)); }
          catch (e) { if (!['not-found', 'permission-denied'].includes(e.code)) throw e; await removePost(post.id, post.get('authorId')); }
        });
      }
    } while (cursor);
    if (failures) throw Error(`Community cleanup requires retry (${failures} jobs)`);
  }
  return {cleanupSource, cleanupAccount, sweep};
};
