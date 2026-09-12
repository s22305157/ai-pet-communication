const {Timestamp} = require('firebase-admin/firestore');
const P = require('./journal_policy');
const stamp = ms => Timestamp.fromMillis(ms);
module.exports = function register({handlers, db, bucket, now, access, mutate, posts, auth, liveSource, notify, paginate}) {
  const admin = async (tx, request) => {
    const uid = auth(request);
    if (request.auth.token?.pilotAdmin !== true) P.fail('permission-denied', '需要試營運管理權限');
    await access(tx, uid);
    return uid;
  };
  const audit = (tx, uid, d, action, details) => tx.create(db.collection('_pilotAdminAudit').doc(`m3_${uid}_${P.id(d.operationId)}`), {
    actor: uid, action, details, createdAt: stamp(now()), schemaVersion: 1});
  handlers.adminGetPilotDashboard = async request => db.runTransaction(async tx => {
    await admin(tx, request);
    const flags = await tx.get(db.doc('pilotConfig/features'));
    const participants = await tx.get(db.collection('pilotParticipants').limit(501));
    const reports = await tx.get(db.collection('communityReports').where('status', '==', 'open').limit(501));
    const events = await tx.get(db.collectionGroup('pilotEvents').where('createdAt', '>=', stamp(now() - 7 * 86400000)).limit(5001));
    const measured = new Set(participants.docs.filter(p => p.get('metricsConsent') === true && !p.get('isTest') && !p.get('isAdmin')).map(p => p.id));
    const counts = {};
    for (const e of events.docs.slice(0, 5000)) {
      if (measured.has(e.ref.parent.parent.id)) counts[e.get('type')] = (counts[e.get('type')] || 0) + 1;
    }
    return {flags: {journalEnabled: flags.get('journalEnabled') === true, reviewEnabled: flags.get('reviewEnabled') === true,
      communityEnabled: flags.get('communityEnabled') === true, communityWriteEnabled: flags.get('communityWriteEnabled') !== false},
    participants: participants.size, openReports: reports.size, suspended: participants.docs.filter(p => p.get('postingSuspended')).length,
    lastSevenDayEvents: counts, truncated: participants.size > 500 || reports.size > 500 || events.size > 5000};
  });
  handlers.adminListPilotData = async request => {
    const d = request.data || {};
    return db.runTransaction(async tx => {
      await admin(tx, request);
      if (d.kind === 'participants') {
        let q = db.collection('pilotParticipants').orderBy('__name__').limit(21);
        if (d.cursor?.id) q = q.startAfter(P.id(d.cursor.id));
        const rows = await tx.get(q), items = rows.docs.slice(0, 20).map(p => ({id: p.id, status: p.get('status') || 'disabled',
          expiresAtMs: P.millis(p.get('expiresAt')), trialEndsAtMs: P.millis(p.get('trialEndsAt')), isTest: p.get('isTest') === true,
          postingSuspended: p.get('postingSuspended') === true}));
        return {items, cursor: rows.size > 20 ? {id: items.at(-1).id} : null};
      }
      if (d.kind === 'audit') return paginate(tx, db.collection('_pilotAdminAudit').orderBy('createdAt', 'desc').orderBy('__name__', 'desc'), d.cursor,
        async a => ({id: a.id, actor: a.get('actor') || '維護工具', action: a.get('action') || 'participant', details: a.get('details') || {}, createdAtMs: P.millis(a.get('createdAt'))}));
      if (d.kind !== 'reports') P.fail('invalid-argument', '管理項目不正確');
      return paginate(tx, db.collection('communityReports').orderBy('createdAt', 'desc').orderBy('__name__', 'desc'), d.cursor, async r => {
        const post = await tx.get(posts(r.get('postId')));
        const content = r.get('commentId') ? await tx.get(posts(r.get('postId')).collection('comments').doc(r.get('commentId'))) : post;
        let available = post.exists && ['published', 'hidden'].includes(post.get('status')) && content.exists && ['published', 'hidden'].includes(content.get('status'));
        if (available) {
          try { await liveSource(tx, post); }
          catch (e) { if (!['not-found', 'permission-denied'].includes(e.code)) throw e; available = false; }
        }
        return {id: r.id, status: r.get('status'), reason: r.get('reason'), revision: r.get('revision'), postId: r.get('postId'),
          commentId: r.get('commentId'), authorUid: r.get('authorId'), text: available ? content.get('text') : '內容已撤回或來源已刪除',
          alias: available ? content.get('alias') : '', mediaIds: available && !r.get('commentId') ? post.get('mediaIds') || [] : [],
          contentStatus: available ? content.get('status') : 'unavailable',
          contentRevision: content.get('revision') || 0, createdAtMs: P.millis(r.get('createdAt'))};
      });
    });
  };
  handlers.adminGetReportedImage = async request => {
    const d = request.data || {};
    const check = async tx => {
      await admin(tx, request);
      const report = await tx.get(db.collection('communityReports').doc(P.id(d.reportId)));
      if (!report.exists || report.get('commentId')) P.fail('not-found', '檢舉沒有圖片');
      const post = await tx.get(posts(report.get('postId')));
      if (!post.exists || !['published', 'hidden'].includes(post.get('status')) || !(post.get('mediaIds') || []).includes(P.id(d.mediaId))) P.fail('not-found', '分享圖片已撤回');
      await liveSource(tx, post);
      return `communityImages/${post.get('authorId')}/${post.id}/${d.mediaId}.jpg`;
    };
    const path = await db.runTransaction(check), [bytes] = await bucket.file(path).download();
    if (path !== await db.runTransaction(check)) P.fail('not-found', '分享圖片已撤回');
    return {base64: bytes.toString('base64')};
  };
  handlers.adminSetPilotFlags = request => mutate(request, 'adminFlags', async ({tx, uid, d}) => {
    await admin(tx, request);
    const keys = ['journalEnabled', 'reviewEnabled', 'communityEnabled', 'communityWriteEnabled'];
    if (!d.flags || !Object.keys(d.flags).length || Object.keys(d.flags).some(k => !keys.includes(k) || typeof d.flags[k] !== 'boolean')) P.fail('invalid-argument', '開關格式不正確');
    tx.set(db.doc('pilotConfig/features'), {...d.flags, schemaVersion: 1}, {merge: true});
    audit(tx, uid, d, 'flags', d.flags);
    return {saved: true};
  }, {readOnly: true});
  handlers.adminSetPostingSuspended = request => mutate(request, 'adminSuspend', async ({tx, uid, d}) => {
    await admin(tx, request);
    const targetId = P.id(d.uid), reason = P.text(d.reason, 500, true);
    if (typeof d.suspended !== 'boolean') P.fail('invalid-argument', '停權狀態不正確');
    await access(tx, targetId);
    const p = await tx.get(db.doc(`pilotParticipants/${targetId}`));
    if (!p.exists) P.fail('not-found', '找不到試營運資格');
    tx.update(p.ref, {postingSuspended: d.suspended});
    notify(tx, targetId, `moderation_${d.operationId}`, {type: 'moderation', message: `${d.suspended ? '已暫停發文與互動' : '已恢復發文與互動'}：${reason}`});
    audit(tx, uid, d, 'posting_suspended', {uid: targetId, suspended: d.suspended, reason});
    return {saved: true};
  }, {readOnly: true});
  handlers.adminModerateCommunity = request => mutate(request, 'adminModerate', async ({tx, uid, d}) => {
    await admin(tx, request);
    if (!['hide', 'restore', 'dismiss'].includes(d.action)) P.fail('invalid-argument', '管理動作不正確');
    const reason = P.text(d.reason, 500, true), ref = db.collection('communityReports').doc(P.id(d.reportId)), report = await tx.get(ref);
    if (!report.exists || report.get('revision') !== d.expectedRevision) P.fail('aborted', '檢舉已由其他管理者處理');
    const post = await tx.get(posts(report.get('postId')));
    const content = report.get('commentId') ? await tx.get(posts(report.get('postId')).collection('comments').doc(report.get('commentId'))) : post;
    if (d.action !== 'dismiss') {
      if (!content.exists || !['published', 'hidden'].includes(content.get('status')) || content.get('revision') !== d.contentRevision) P.fail('aborted', '內容已變更或撤回');
      await liveSource(tx, post);
    }
    if (d.action !== 'dismiss') {
      const status = d.action === 'hide' ? 'hidden' : 'published';
      tx.update(content.ref, {status, revision: content.get('revision') + 1});
      if (report.get('commentId') && content.get('status') !== status) tx.update(post.ref, {commentCount: Math.max(0, (post.get('commentCount') || 0) + (status === 'published' ? 1 : -1))});
      notify(tx, report.get('authorId'), `moderation_${d.operationId}`, {type: 'moderation', message: `${d.action === 'hide' ? '社群內容已隱藏' : '社群內容已恢復'}：${reason}`});
    }
    tx.update(ref, {status: 'resolved', revision: report.get('revision') + 1, resolvedAt: stamp(now())});
    notify(tx, report.get('reporterId'), `report_${d.operationId}`, {type: 'moderation', message: `檢舉已處理：${reason}`});
    audit(tx, uid, d, d.action, {reportId: report.id, reason});
    return {saved: true};
  }, {readOnly: true});
};
