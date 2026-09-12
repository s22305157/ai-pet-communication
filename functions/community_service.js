const {createHash, randomUUID} = require('node:crypto');
const {Timestamp, FieldValue} = require('firebase-admin/firestore');
const P = require('./journal_policy');
const stamp = ms => Timestamp.fromMillis(ms);
const TOPICS = ['毛孩到家', '熟悉彼此', '今天的小進步'];
module.exports = function createCommunity(ctx) {
  const {handlers, db, bucket, now, access, livePet, mutate, event} = ctx;
  const users = uid => db.collection('users').doc(uid);
  const posts = id => db.collection('communityPosts').doc(P.id(id));
  const authorKey = uid => createHash('sha256').update(`community:${uid}`).digest('hex').slice(0, 32);
  const auth = request => { if (!request.auth?.uid) P.fail('unauthenticated', '請先登入'); return request.auth.uid; };
  async function member(tx, uid, write = false) {
    const a = await access(tx, uid);
    if (!a.invited || !a.p.activatedAt || a.config.communityEnabled !== true) P.fail('permission-denied', '同伴圈只向有效受邀會員開放');
    if (write && (a.config.communityWriteEnabled === false || a.p.postingSuspended === true)) P.fail('permission-denied', '目前暫停發文與互動');
    return a;
  }
  async function blocked(tx, a, b) {
    if (a === b) return false;
    const rows = await Promise.all([tx.get(users(a).collection('communityBlocks').doc(authorKey(b))), tx.get(users(b).collection('communityBlocks').doc(authorKey(a)))]);
    return rows.some(s => s.exists);
  }
  async function liveSource(tx, post) {
    await access(tx, post.get('authorId'));
    const pet = await livePet(tx, post.get('authorId'), post.get('petId'));
    const entry = await tx.get(pet.ref.collection('entries').doc(post.get('entryId')));
    if (!entry.exists || entry.get('deletedAt')) P.fail('not-found', '來源日記已刪除');
    return entry;
  }
  async function visiblePost(tx, uid, id, own = false) {
    const post = await tx.get(posts(id));
    if (!post.exists || (post.get('status') !== 'published' && !(own && post.get('authorId') === uid && post.get('status') === 'hidden'))) P.fail('not-found', '貼文已移除或無法查看');
    await liveSource(tx, post);
    if (await blocked(tx, uid, post.get('authorId'))) P.fail('not-found', '貼文無法查看');
    return post;
  }
  const postView = (p, uid) => ({id: p.id, alias: p.get('alias'), authorKey: authorKey(p.get('authorId')), own: p.get('authorId') === uid,
    text: p.get('text'), topic: p.get('topic'), status: p.get('status'), revision: p.get('revision'), mediaIds: p.get('mediaIds') || [],
    commentCount: p.get('commentCount') || 0, encouragementCount: p.get('encouragementCount') || 0, createdAtMs: P.millis(p.get('createdAt'))});
  async function daily(tx, uid, kind, max) {
    const ref = users(uid).collection('communityLimits').doc(kind), s = await tx.get(ref), day = P.dayKey(now());
    const count = s.get('day') === day ? s.get('count') || 0 : 0;
    if (count >= max) P.fail('resource-exhausted', '已達今日社群使用上限');
    return () => tx.set(ref, {day, count: count + 1});
  }
  function notify(tx, uid, id, data) {
    tx.set(users(uid).collection('pilotNotifications').doc(id), {...data, read: false, createdAt: stamp(now()), schemaVersion: 1});
  }
  async function paginate(tx, query, cursor, view) {
    if (cursor) query = query.startAfter(stamp(P.time(cursor.time, now())), P.id(cursor.id));
    const rows = await tx.get(query.limit(80)), items = [];
    let last, consumed = 0;
    for (const row of rows.docs) {
      last = row; consumed++;
      try { const value = await view(row); if (value) items.push(value); }
      catch (e) { if (!['not-found', 'permission-denied'].includes(e.code)) throw e; }
      if (items.length === 20) break;
    }
    return {items, cursor: last && (consumed < rows.size || rows.size === 80) ? {time: P.millis(last.get('createdAt')), id: last.id} : null};
  }
  const shared = {...ctx, users, posts, authorKey, auth, member, blocked, liveSource, visiblePost, postView, daily, notify, paginate, TOPICS};
  require('./community_interactions')(shared);
  require('./pilot_admin_service')(shared);
  const cleanup = require('./community_cleanup_service')(shared);
  handlers.publishCommunityPost = async request => {
    const result = await mutate(request, 'publishPost', async ({tx, uid, d}) => {
      await member(tx, uid, true);
      if (!TOPICS.includes(d.topic) || d.confirmed !== true) P.fail('invalid-argument', '請先預覽並確認分享範圍');
      const text = P.text(d.text, 3000), alias = P.text(d.alias, 40, true);
      const pet = await livePet(tx, uid, d.petId), entry = await tx.get(pet.ref.collection('entries').doc(P.id(d.entryId)));
      if (!entry.exists || entry.get('deletedAt') || entry.get('revision') !== d.expectedRevision) P.fail('aborted', '來源日記已變更，請重新預覽');
      if (!Array.isArray(d.mediaIds) || d.mediaIds.length > 3 || new Set(d.mediaIds).size !== d.mediaIds.length ||
          d.mediaIds.some(id => !(entry.get('mediaIds') || []).includes(id)) || (!text && !d.mediaIds.length)) P.fail('invalid-argument', '請選擇日記文字或照片');
      const media = await Promise.all(d.mediaIds.map(id => tx.get(users(uid).collection('journalMedia').doc(P.id(id)))));
      if (media.some(m => m.get('status') !== 'ready' || m.get('entryId') !== entry.id || m.get('petId') !== pet.id)) P.fail('not-found', '來源圖片無法分享');
      const useQuota = await daily(tx, uid, 'posts', 5);
      const ref = db.collection('communityPosts').doc();
      tx.create(ref, {authorId: uid, alias, petId: pet.id, entryId: entry.id, sourceRevision: entry.get('revision'),
        text, topic: d.topic, mediaIds: d.mediaIds, copies: media.map(m => ({id: m.id, source: m.get('path')})),
        status: 'preparing', revision: 1, createdAt: stamp(now()), schemaVersion: 1, commentCount: 0, encouragementCount: 0});
      tx.set(db.collection('_communityCleanup').doc(ref.id), {postId: ref.id, uid, nextAt: stamp(now() + 86400000)});
      useQuota();
      return {postId: ref.id};
    }, {readOnly: true});
    const uid = auth(request), ref = posts(result.postId), copyLeaseId = randomUUID();
    const check = async tx => {
      await member(tx, uid, true);
      const post = await tx.get(ref);
      if (!post.exists || post.get('authorId') !== uid || !['preparing', 'published'].includes(post.get('status'))) P.fail('not-found', '分享已撤回或失敗');
      const source = await liveSource(tx, post);
      if (post.get('status') === 'preparing' && source.get('revision') !== post.get('sourceRevision')) P.fail('aborted', '來源已變更，請重新預覽');
      return post;
    };
    try {
      const post = await db.runTransaction(async tx => {
        const p = await check(tx);
        if (p.get('status') === 'published') return p;
        if (P.millis(p.get('copyLeaseUntil')) > now()) P.fail('unavailable', '分享處理中，請稍後重試');
        tx.update(ref, {copyLeaseId, copyLeaseUntil: stamp(now() + 120000)});
        return p;
      });
      if (post.get('status') === 'published') return result;
      for (const m of post.get('copies')) {
        const target = bucket.file(`communityImages/${uid}/${post.id}/${m.id}.jpg`);
        await bucket.file(m.source).copy(target);
        await target.setMetadata({cacheControl: 'private, no-store', metadata: {firebaseStorageDownloadTokens: null}});
      }
      await db.runTransaction(async tx => {
        const current = await check(tx);
        if (current.get('status') !== 'preparing') return;
        if (current.get('copyLeaseId') !== copyLeaseId) P.fail('unavailable', '分享正在重試，請稍後查看');
        const a = await access(tx, uid);
        if (request.auth.token?.pilotAdmin === true) a.p = {...a.p, isAdmin: true};
        tx.update(ref, {status: 'published', copies: FieldValue.delete(), copyLeaseId: FieldValue.delete(), copyLeaseUntil: FieldValue.delete()});
        event(tx, uid, a, 'post_created', request.data.operationId, ref.id);
        tx.delete(db.collection('_communityCleanup').doc(ref.id));
      });
      return result;
    } catch (error) {
      await db.runTransaction(async tx => {
        const p = await tx.get(ref);
        if (p.exists && p.get('status') === 'preparing' && p.get('copyLeaseId') === copyLeaseId) {
          tx.update(ref, {status: 'failed', text: '', mediaIds: [], copies: FieldValue.delete()});
          tx.set(db.collection('_communityCleanup').doc(ref.id), {postId: ref.id, uid, nextAt: stamp(now())});
        }
        if (!p.exists || ['withdrawn', 'failed'].includes(p.get('status'))) {
          // A cleanup job may have finished during a late Storage write. Re-enqueue it.
          tx.set(db.collection('_communityCleanup').doc(ref.id), {postId: ref.id, uid, nextAt: stamp(now())});
        }
      });
      throw error;
    }
  };
  handlers.listCommunityPosts = async request => {
    const uid = auth(request), d = request.data || {};
    return db.runTransaction(async tx => {
      await member(tx, uid);
      let query = db.collection('communityPosts').orderBy('createdAt', 'desc').orderBy('__name__', 'desc');
      if (d.mine === true) query = query.where('authorId', '==', uid);
      else if (d.topic) { if (!TOPICS.includes(d.topic)) P.fail('invalid-argument', '主題不正確'); query = query.where('topic', '==', d.topic); }
      return paginate(tx, query, d.cursor, async s => postView(await visiblePost(tx, uid, s.id, d.mine === true), uid));
    });
  };
  handlers.getCommunityPost = async request => {
    const uid = auth(request);
    return db.runTransaction(async tx => {
      await member(tx, uid);
      const p = await visiblePost(tx, uid, request.data?.postId, true);
      const reaction = await tx.get(p.ref.collection('encouragements').doc(uid));
      return {...postView(p, uid), encouraged: reaction.exists};
    });
  };
  handlers.editCommunityPost = request => mutate(request, 'editPost', async ({tx, uid, d}) => {
    await member(tx, uid, true);
    const post = await visiblePost(tx, uid, d.postId, true);
    if (post.get('authorId') !== uid) P.fail('permission-denied', '只能編輯自己的貼文');
    if (post.get('revision') !== d.expectedRevision) P.fail('aborted', '貼文已有新版本');
    const text = P.text(d.text, 3000);
    if ((!text && !post.get('mediaIds').length) || !TOPICS.includes(d.topic)) P.fail('invalid-argument', '貼文內容或主題不正確');
    tx.update(post.ref, {text, topic: d.topic, revision: post.get('revision') + 1, updatedAt: stamp(now())});
    return {saved: true};
  }, {readOnly: true});
  handlers.withdrawCommunityPost = request => mutate(request, 'withdrawPost', async ({tx, uid, d}) => {
    const post = await tx.get(posts(d.postId));
    if (!post.exists || post.get('authorId') !== uid) P.fail('not-found', '找不到自己的貼文');
    if (post.get('status') === 'withdrawn') return {withdrawn: true};
    if (post.get('revision') !== d.expectedRevision) P.fail('aborted', '貼文已有新版本');
    tx.update(post.ref, {status: 'withdrawn', text: '', mediaIds: [], copies: FieldValue.delete(), revision: post.get('revision') + 1});
    tx.set(db.collection('_communityCleanup').doc(post.id), {uid, postId: post.id, nextAt: stamp(now())});
    return {withdrawn: true};
  }, {readOnly: true});
  handlers.getCommunityImage = async request => {
    const uid = auth(request), d = request.data || {};
    const check = async tx => {
      await member(tx, uid);
      const post = await visiblePost(tx, uid, d.postId, true), mid = P.id(d.mediaId);
      if (!post.get('mediaIds').includes(mid)) P.fail('not-found', '分享圖片已移除');
      return `communityImages/${post.get('authorId')}/${post.id}/${mid}.jpg`;
    };
    const path = await db.runTransaction(check), [bytes] = await bucket.file(path).download();
    if (await db.runTransaction(check) !== path) P.fail('not-found', '分享圖片已移除');
    return {base64: bytes.toString('base64')};
  };
  return cleanup;
};
