const {Timestamp} = require('firebase-admin/firestore');
const P = require('./journal_policy');
const stamp = ms => Timestamp.fromMillis(ms);
module.exports = function register({handlers, db, now, access, livePet, mutate, event, users, posts, authorKey, auth, member, blocked, visiblePost, daily, notify, paginate}) {
  async function visibleComment(tx, uid, post, id) {
    const comment = await tx.get(post.ref.collection('comments').doc(P.id(id)));
    if (!comment.exists || comment.get('status') !== 'published' || await blocked(tx, uid, comment.get('authorId'))) P.fail('not-found', '留言已移除');
    await access(tx, comment.get('authorId'));
    return comment;
  }
  async function target(tx, uid, d) {
    const post = await visiblePost(tx, uid, d.postId);
    return d.commentId ? visibleComment(tx, uid, post, d.commentId) : post;
  }
  handlers.addCommunityComment = request => mutate(request, 'comment', async ({tx, uid, d, a}) => {
    await member(tx, uid, true);
    if (d.parentId) P.fail('invalid-argument', '目前只開放一層留言');
    const post = await visiblePost(tx, uid, d.postId);
    const text = P.text(d.text, 500, true), alias = P.text(d.alias, 40, true), useQuota = await daily(tx, uid, 'comments', 30);
    const ref = post.ref.collection('comments').doc();
    tx.create(ref, {authorId: uid, alias, text, postId: post.id, revision: 1, status: 'published', createdAt: stamp(now()), schemaVersion: 1});
    tx.update(post.ref, {commentCount: (post.get('commentCount') || 0) + 1});
    if (post.get('authorId') !== uid) notify(tx, post.get('authorId'), `comment_${ref.id}`, {type: 'comment', postId: post.id, commentId: ref.id, actorId: uid});
    useQuota(); event(tx, uid, a, 'comment_created', d.operationId, post.id);
    return {commentId: ref.id};
  }, {readOnly: true});
  handlers.listCommunityComments = async request => {
    const uid = auth(request), d = request.data || {};
    return db.runTransaction(async tx => {
      await member(tx, uid);
      const post = await visiblePost(tx, uid, d.postId, true);
      return paginate(tx, post.ref.collection('comments').orderBy('createdAt', 'desc').orderBy('__name__', 'desc'), d.cursor, async s => {
        const c = await visibleComment(tx, uid, post, s.id);
        return {id: c.id, text: c.get('text'), alias: c.get('alias'), authorKey: authorKey(c.get('authorId')),
          own: c.get('authorId') === uid, revision: c.get('revision'), createdAtMs: P.millis(c.get('createdAt'))};
      });
    });
  };
  handlers.deleteCommunityComment = request => mutate(request, 'deleteComment', async ({tx, uid, d}) => {
    const post = await tx.get(posts(d.postId));
    const comment = await tx.get(posts(d.postId).collection('comments').doc(P.id(d.commentId)));
    if (!comment.exists || comment.get('authorId') !== uid) P.fail('not-found', '找不到自己的留言');
    if (comment.get('status') === 'deleted') return {deleted: true};
    if (comment.get('revision') !== d.expectedRevision) P.fail('aborted', '留言已有新版本');
    tx.update(comment.ref, {status: 'deleted', text: '', revision: comment.get('revision') + 1});
    if (post.exists && comment.get('status') === 'published') tx.update(post.ref, {commentCount: Math.max(0, (post.get('commentCount') || 0) - 1)});
    return {deleted: true};
  }, {readOnly: true});
  handlers.encourageCommunityPost = request => mutate(request, 'encourage', async ({tx, uid, d, a}) => {
    await member(tx, uid, true);
    const post = await visiblePost(tx, uid, d.postId), ref = post.ref.collection('encouragements').doc(uid), previous = await tx.get(ref);
    const noteRef = users(post.get('authorId')).collection('pilotNotifications').doc(`encouragement_${post.id}`);
    const note = await tx.get(noteRef);
    if (!previous.exists) {
      tx.create(ref, {authorId: uid, postId: post.id, createdAt: stamp(now()), schemaVersion: 1});
      tx.update(post.ref, {encouragementCount: (post.get('encouragementCount') || 0) + 1});
      if (post.get('authorId') !== uid) notify(tx, post.get('authorId'), noteRef.id,
        {type: 'encouragement', postId: post.id, actorIds: [...new Set([...(note.get('actorIds') || []), uid])].slice(-100)});
      event(tx, uid, a, 'encouragement_created', d.operationId, post.id);
    }
    return {encouraged: true};
  }, {readOnly: true});
  handlers.reportCommunityContent = request => mutate(request, 'report', async ({tx, uid, d}) => {
    await member(tx, uid);
    const content = await target(tx, uid, d), reason = P.text(d.reason, 500, true);
    const ref = db.collection('communityReports').doc(`${uid}_${d.postId}_${d.commentId || 'post'}`), previous = await tx.get(ref);
    if (!previous.exists) tx.create(ref, {reporterId: uid, authorId: content.get('authorId'), postId: d.postId,
      commentId: d.commentId || null, reason, status: 'open', revision: 1, createdAt: stamp(now()), schemaVersion: 1});
    return {reported: true};
  }, {readOnly: true});
  handlers.blockCommunityAuthor = request => mutate(request, 'block', async ({tx, uid, d}) => {
    await member(tx, uid);
    const content = await target(tx, uid, d), targetId = content.get('authorId');
    if (uid === targetId) P.fail('invalid-argument', '不能封鎖自己');
    tx.set(users(uid).collection('communityBlocks').doc(authorKey(targetId)), {targetId, alias: content.get('alias'), createdAt: stamp(now())});
    return {blocked: true};
  }, {readOnly: true});
  handlers.listCommunityBlocks = async request => {
    const uid = auth(request), d = request.data || {};
    return db.runTransaction(async tx => {
      await access(tx, uid);
      return paginate(tx, users(uid).collection('communityBlocks').orderBy('createdAt', 'desc').orderBy('__name__', 'desc'), d.cursor,
        async row => ({id: row.id, alias: row.get('alias')}));
    });
  };
  handlers.unblockCommunityAuthor = request => mutate(request, 'unblock', async ({tx, uid, d}) => {
    tx.delete(users(uid).collection('communityBlocks').doc(P.id(d.blockId)));
    return {unblocked: true};
  }, {readOnly: true});
  handlers.listPilotNotifications = async request => {
    const uid = auth(request), d = request.data || {};
    return db.runTransaction(async tx => {
      await access(tx, uid);
      return paginate(tx, users(uid).collection('pilotNotifications').orderBy('createdAt', 'desc').orderBy('__name__', 'desc'), d.cursor, async row => {
        const type = row.get('type');
        const value = {id: row.id, type, read: row.get('read') === true, createdAtMs: P.millis(row.get('createdAt'))};
        if (type === 'review') {
          const pet = await livePet(tx, uid, row.get('petId')), review = await tx.get(pet.ref.collection('weeklyReviews').doc(row.get('week')));
          if (review.get('status') !== 'ready') return null;
          for (const source of review.get('sources') || []) {
            const e = await tx.get(pet.ref.collection('entries').doc(source.entryId));
            if (!e.exists || e.get('deletedAt') || e.get('revision') !== source.revision) return null;
          }
          return {...value, petId: pet.id, week: row.get('week')};
        }
        if (type === 'moderation') return {...value, message: row.get('message')};
        await member(tx, uid);
        const post = await visiblePost(tx, uid, row.get('postId'));
        if (type === 'comment') await visibleComment(tx, uid, post, row.get('commentId'));
        if (type === 'encouragement') {
          let visible = 0;
          for (const id of row.get('actorIds') || []) {
            try { await access(tx, id); if (!await blocked(tx, uid, id)) visible++; }
            catch (e) { if (e.code !== 'permission-denied') throw e; }
          }
          if (!visible) return null;
          value.count = visible;
        }
        return {...value, postId: post.id};
      });
    });
  };
  handlers.markPilotNotificationRead = request => mutate(request, 'readNotification', async ({tx, uid, d}) => {
    const ref = users(uid).collection('pilotNotifications').doc(P.id(d.notificationId)), s = await tx.get(ref);
    if (s.exists) tx.update(ref, {read: true});
    return {saved: true};
  }, {readOnly: true});
};
