const {createHash} = require('node:crypto');
const {getFirestore, Timestamp, FieldValue} = require('firebase-admin/firestore');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {defineSecret, defineString, defineBoolean} = require('firebase-functions/params');
const {validateRequest, route, emergencyResponse} = require('./ai_contract');
const {generate} = require('./openai_provider');
const {searchKnowledge} = require('./knowledge_retrieval');
const {effectiveTier} = require('./subscription_policy');

// Reuse the existing Luna credential for every tier; keep it in Secret Manager.
const apiKey = defineSecret('OPENAI_API_KEY_PRO');
const enabled = defineBoolean('AI_ENABLED', {default: false});
const allAuthenticated = defineBoolean('AI_ALL_AUTHENTICATED', {default: false});
const model = defineString('OPENAI_MODEL', {default: 'gpt-5.6-luna'});
const allowedUids = defineString('AI_ALLOWED_UIDS', {default: ''});

// Dependency injection keeps authorization, concurrency and billing testable offline.
function createHandler({db, config, provider = generate, retrieve = searchKnowledge, now = Date.now}) {
  return async request => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', '請先登入');
    const settings = config();
    if (!settings.enabled) throw new HttpsError('failed-precondition', 'AI 服務尚未開放');
    if (settings.allAuthenticated !== true && !settings.allowedUids.split(',').map(value => value.trim()).filter(Boolean).includes(uid)) {
      throw new HttpsError('permission-denied', '此帳號尚未開放 AI 試用');
    }
    let input;
    try { input = validateRequest(request.data); } catch (error) {
      if (error instanceof HttpsError) throw error;
      throw new HttpsError('invalid-argument', 'Invalid AI request');
    }
    const {requestId, petId} = input;
    const userRef = db.collection('users').doc(uid);
    const deletedRef = db.collection('_deletedUsers').doc(uid);
    const petRef = db.collection('pets').doc(petId);
    const tombstoneRef = db.collection('petTombstones').doc(petId);
    const operationRef = userRef.collection('aiRequests').doc(requestId);
    const quotaRef = db.collection('_aiRateLimits').doc(uid);
    const globalRef = db.collection('_aiGlobalLimits').doc('daily');
    const hash = createHash('sha256').update(JSON.stringify(input)).digest('hex');
    const timestamp = now();
    const day = new Date(timestamp).toISOString().slice(0, 10);
    const claim = await db.runTransaction(async tx => {
      const [user, deleted, pet, tombstone, operation, quota, globalQuota] = await Promise.all(
        [userRef, deletedRef, petRef, tombstoneRef, operationRef, quotaRef, globalRef].map(ref => tx.get(ref)));
      if (!user.exists || deleted.exists) throw new HttpsError('permission-denied', 'Account is inactive');
      if (tombstone.exists || (pet.exists && pet.get('owner_id') !== uid)) {
        throw new HttpsError('permission-denied', '無法存取此毛孩');
      }
      if (operation.exists) {
        if (operation.get('hash') !== hash) throw new HttpsError('already-exists', '請勿重用請求編號');
        if (operation.get('status') === 'completed') return {cached: operation.get('response')};
        throw new HttpsError('failed-precondition', '此請求已處理或仍在處理中，請重新開始');
      }
      if (!['free', 'plus', 'pro'].includes(user.get('membershipTier'))) throw new HttpsError('permission-denied', '此方案尚未開放 AI 溝通');
      const tier = effectiveTier(user.data(), timestamp);
      const selectedModel = settings.model?.trim();
      if (!selectedModel) throw new HttpsError('failed-precondition', 'AI 模型尚未設定');
      const selectedKey = settings.apiKey;
      if (typeof selectedKey !== 'string' || !selectedKey.trim()) {
        throw new HttpsError('failed-precondition', 'AI 金鑰尚未設定');
      }
      if (tier !== 'free' && !pet.exists) throw new HttpsError('not-found', '請先同步毛孩檔案');
      const q = quota.data() || {};
      const g = globalQuota.data() || {};
      const minuteCount = timestamp - (q.windowStartMs || 0) < 60000 ? (q.minuteCount || 0) : 0;
      const dayCount = q.day === day ? (q.dayCount || 0) : 0;
      const globalCount = g.day === day ? (g.dayCount || 0) : 0;
      if (minuteCount >= 5 || dayCount >= 30 || globalCount >= 100) {
        throw new HttpsError('resource-exhausted', '已達 AI 試用次數上限，請稍後再試');
      }
      tx.set(quotaRef, {windowStartMs: minuteCount ? q.windowStartMs : timestamp,
        minuteCount: minuteCount + 1, day, dayCount: dayCount + 1});
      tx.set(globalRef, {day, dayCount: globalCount + 1});
      tx.create(operationRef, {hash, petId, model: selectedModel, membershipTier: tier,
        status: 'processing', createdAt: Timestamp.fromMillis(timestamp)});
      return {tier, model: selectedModel};
    });
    if (claim.cached) return {response: claim.cached};
    try {
      input.request.inputMode = claim.tier;
      const decision = route(input.request);
      let value;
      if (decision.level === 'emergency') {
        value = emergencyResponse(decision);
      } else {
        const knowledge = await retrieve({query: [input.request.petProfile.species,
          input.request.ownerProfile.mainConcern, input.request.story, ...input.request.questions].join(' ').slice(0, 7000),
        species: input.request.petProfile.species, limit: 4});
        value = await provider({apiKey: settings.apiKey, model: claim.model,
          request: input.request, decision, knowledge});
      }
      const response = JSON.stringify(value);
      await db.runTransaction(async tx => {
        const [user, deleted, tombstone] = await Promise.all(
          [userRef, deletedRef, tombstoneRef].map(ref => tx.get(ref)));
        if (!user.exists || deleted.exists || tombstone.exists) throw new HttpsError('permission-denied', 'Account or pet is inactive');
        tx.update(operationRef, {status: 'completed', response, completedAt: FieldValue.serverTimestamp()});
      });
      return {response};
    } catch (error) {
      // Mark failed requests without reading or writing points; pricing is pending.
      await db.runTransaction(async tx => {
        const operation = await tx.get(operationRef);
        if (operation.exists && operation.get('status') === 'processing') {
          tx.update(operationRef, {status: 'failed'});
        }
      });
      if (error instanceof HttpsError) throw error;
      throw new HttpsError('unavailable', 'AI 服務暫時無法使用');
    }
  };
}

exports.communicateWithPet = onCall({maxInstances: 3, concurrency: 10, timeoutSeconds: 90,
  secrets: [apiKey, 'KB_ENCRYPTION_KEY']}, request => createHandler({
  db: getFirestore(), config: () => ({enabled: enabled.value(), allAuthenticated: allAuthenticated.value(),
    model: model.value(), apiKey: apiKey.value(),
    allowedUids: allowedUids.value()}),
})(request));
exports.createHandler = createHandler;
