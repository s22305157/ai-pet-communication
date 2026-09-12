const test = require('node:test');
const assert = require('node:assert/strict');
const {createHandler} = require('../ai_operations');
const {generate} = require('../openai_provider');
const {validateRequest, route, emergencyResponse, validateResponse} = require('../ai_contract');

const requestId = 'request-0000000001';
const payload = () => ({requestId, petId: 'pet1', request: {
  ownerProfile: {experienceLevel: '', careStyle: '', emotionStyle: '', dailyRoutine: '', mainConcern: ''},
  petProfile: {name: '毛孩', species: '貓', breed: '', age: null, coatColor: '', personalityTraits: []},
  story: '今天精神很好', questions: ['牠開心嗎？'], inputMode: 'pro', media: null,
}});
const safe = () => ({...emergencyResponse({matched: []}),
  safety_alert: {has_red_flags: false, message: '資料不足，請持續觀察。', red_flags: []},
  next_steps: ['請記錄活動與食慾變化。']});

test('every tier waits for RAG and passes retrieved knowledge to generation', async () => {
  for (const tier of ['free', 'plus', 'pro']) {
    let release, started;
    const gate = new Promise(resolve => { release = resolve; });
    const entered = new Promise(resolve => { started = resolve; });
    const knowledge = [{title: '陪伴', content: '等待毛孩主動靠近，不強迫互動。'}];
    const h = harness(tier, {retrieve: async query => {
      assert(query.query.includes('牠開心嗎？'));
      started(); await gate; return knowledge;
    }});
    const response = h.call();
    await entered;
    assert.equal(h.calls.length, 0);
    release(); await response;
    assert.deepEqual(h.calls[0].knowledge, knowledge);
  }
});

test('RAG failure never falls through to ungrounded model generation', async () => {
  const h = harness('plus', {retrieve: async () => { throw new Error('index unavailable'); }});
  await assert.rejects(h.call(), {code: 'unavailable'});
  assert.equal(h.calls.length, 0);
  assert.equal(h.docs.get(`users/user1/aiRequests/${requestId}`).status, 'failed');
});

test('only active Plus and Pro pass three owned photos to the provider and cache retries', async () => {
  for (const tier of ['plus', 'pro']) {
    let loads = 0;
    const h = harness(tier, {photos: async () => { loads++; return ['image1', 'image2', 'image3']; }});
    const data = payload();
    data.request.media = {photos: [0, 1, 2].map(i => `communicationPhotos/user1/${requestId}/${i}`)};
    await h.call(data);
    await h.call(data);
    assert.equal(loads, 1);
    assert.deepEqual(h.calls[0].images, ['image1', 'image2', 'image3']);
    assert(!JSON.stringify([...h.docs.values()]).includes('communicationPhotos/'));
  }
});

test('Free, expired and unverified members cannot use photos or consume quota', async () => {
  for (const change of [{membershipTier: 'free', membershipEntitlements: {}},
    {subscriptionVerified: false}, {membershipEntitlements: {}}]) {
    const h = harness('pro', {photos: async () => assert.fail('must not load')});
    Object.assign(h.docs.get('users/user1'), change);
    const data = payload();
    data.request.media = {photos: [`communicationPhotos/user1/${requestId}/0`]};
    await assert.rejects(h.call(data), {code: 'permission-denied'});
    assert.equal(h.calls.length, 0);
    assert(!h.docs.has('_aiRateLimits/user1'));
  }
});

test('foreign, other-request and invalid slots are rejected before reading photos', async () => {
  for (const path of [`communicationPhotos/other/${requestId}/0`,
    'communicationPhotos/user1/another-request-01/0', `communicationPhotos/user1/${requestId}/3`]) {
    const h = harness('plus');
    const data = payload(); data.request.media = {photos: [path]};
    await assert.rejects(h.call(data), {code: 'permission-denied'});
    assert.equal(h.calls.length, 0);
  }
});

test('photo emergencies still bypass image reads and model latency', async () => {
  const h = harness('plus', {photos: async () => assert.fail('must not load')});
  const data = payload(); data.request.story = '呼吸困難';
  data.request.media = {photos: [`communicationPhotos/user1/${requestId}/0`]};
  assert(JSON.parse((await h.call(data)).response).safety_alert.has_red_flags);
  assert.equal(h.calls.length, 0);
});

test('provider receives real image parts alongside text, without private storage paths', async () => {
  const request = {...payload().request, inputMode: 'plus', media: {photos: ['private-path']}};
  await generate({apiKey: 'fake', model: 'test', request, decision: route(request), knowledge: [],
    images: ['data:image/jpeg;base64,photo1', 'data:image/jpeg;base64,photo2'],
    fetchImpl: async (_, options) => {
      const body = JSON.parse(options.body);
      assert.equal(body.input[0].content.length, 3);
      assert.equal(body.input[0].content[1].type, 'input_image');
      assert.equal(body.input[0].content[2].image_url, 'data:image/jpeg;base64,photo2');
      assert(!options.body.includes('private-path'));
      return {ok: true, json: async () => ({status: 'completed', output: [{type: 'message', role: 'assistant',
        content: [{type: 'output_text', text: JSON.stringify(safe())}]}]})};
    }});
});

test('awards persist atomically, ignore supplied IDs and deduplicate retries and later requests', async () => {
  const h = harness('free', {provider: async () => ({...safe(),
    knowledge_tips: ['翻肚不代表同意摸肚子。',
      '洗衣機、烘衣機啟動前先檢查滾筒，平時關好機門。'],
    planetAward: {newCardIds: ['001']}})});
  const first = await h.call({...payload(), cardIds: ['001']});
  assert.deepEqual(JSON.parse(first.response).planetAward, {matchedCardIds: ['020', '100'], newCardIds: ['020', '100']});
  assert(h.docs.has('users/user1/planetCards/020'));
  assert(h.docs.has('users/user1/planetCards/100'));
  assert(!h.docs.has('users/user1/planetCards/001'));
  assert.deepEqual(await h.call({...payload(), cardIds: ['001']}), first);
  const later = await h.call({...payload(), requestId: 'request-0000000002'});
  assert.deepEqual(JSON.parse(later.response).planetAward, {matchedCardIds: ['020', '100'], newCardIds: []});
  assert.equal(h.docs.get('users/user1/planetCards/020').firstRequestId, requestId);
  assert.equal(h.docs.get('users/user1/planetCards/100').firstRequestId, requestId);
});

test('dog knowledge awards dog cards atomically and ignores forged cat receipts', async () => {
  const h = harness('free', {provider: async () => ({...safe(),
    knowledge_tips: ['散步保留安全嗅聞時間，不急著拉走狗狗。',
      '安排安全的挖掘區，使用合適材料並在旁監督。'],
    planetAward: {matchedCardIds: ['001'], newCardIds: ['001']}})});
  const data = payload();
  data.request.petProfile.species = '狗';
  data.cardIds = ['001', '040'];
  const first = await h.call(data);
  assert.deepEqual(JSON.parse(first.response).planetAward, {matchedCardIds: ['021', '080'], newCardIds: ['021', '080']});
  assert(h.docs.has('users/user1/planetCards/021'));
  assert(h.docs.has('users/user1/planetCards/080'));
  assert(!h.docs.has('users/user1/planetCards/001'));
  assert(!h.docs.has('users/user1/planetCards/040'));
  assert.deepEqual(await h.call(data), first);
  const later = await h.call({...data, requestId: 'request-0000000002'});
  assert.deepEqual(JSON.parse(later.response).planetAward, {matchedCardIds: ['021', '080'], newCardIds: []});
  assert.equal(h.docs.get('users/user1/planetCards/021').firstRequestId, requestId);
  assert.equal(h.docs.get('users/user1/planetCards/080').firstRequestId, requestId);
});

function harness(tier = 'free', overrides = {}) {
  const at = Date.now();
  const docs = new Map([
    ['users/user1', {membershipTier: tier, points: 1, subscriptionVerified: true,
      membershipEntitlements: {[tier]: {toMillis: () => at + 3600000}}}],
    ['pets/pet1', {owner_id: 'user1'}],
    [`users/user1/creditOperations/${requestId}`, {kind: 'communication', amount: 1, petId: 'pet1',
      status: 'reserved', expiresAt: {toMillis: () => at + 1800000}}],
  ]);
  const ref = path => ({path, collection: name => ({doc: id => ref(`${path}/${name}/${id}`)})});
  const snapshot = value => ({exists: value !== undefined, data: () => value, get: key => value?.[key]});
  let tail = Promise.resolve();
  const db = {collection: name => ({doc: id => ref(`${name}/${id}`)}),
    runTransaction: fn => {
      const next = tail.then(async () => {
        const writes = [];
        const result = await fn({get: async ref => snapshot(docs.get(ref.path)),
          set: (ref, value) => writes.push(() => docs.set(ref.path, value)),
          create: (ref, value) => writes.push(() => { assert(!docs.has(ref.path)); docs.set(ref.path, value); }),
          update: (ref, value) => writes.push(() => { assert(docs.has(ref.path)); docs.set(ref.path, {...docs.get(ref.path), ...value}); }),
        });
        writes.forEach(write => write());
        return result;
      });
      tail = next.catch(() => {});
      return next;
    }};
  const calls = [];
  const settings = {enabled: true, allowedUids: 'user1',
    apiKey: 'fake-shared-key', model: 'gpt-5.6-luna'};
  const handler = createHandler({db, now: () => at, config: () => settings,
    retrieve: async () => [{content: 'knowledge'}],
    provider: async args => { calls.push(args); return safe(); }, ...overrides});
  return {docs, settings, calls, handler, call: (data = payload()) => handler({auth: {uid: 'user1'}, data})};
}

test('concurrent distinct communications collect a card once', async () => {
  const h = harness('free', {provider: async () => ({...safe(), knowledge_tips: ['線繩玩具用後收妥。']})});
  const results = await Promise.all([h.call(), h.call({...payload(), requestId: 'request-0000000002'})]);
  assert.equal(results.flatMap(r => JSON.parse(r.response).planetAward.newCardIds).length, 1);
  assert(h.docs.has('users/user1/planetCards/019'));
});

test('account deletion during generation cannot create a collection', async () => {
  let h;
  h = harness('free', {provider: async () => {
    h.docs.set('_deletedUsers/user1', {});
    return {...safe(), knowledge_tips: ['翻肚不代表同意摸肚子。']};
  }});
  await assert.rejects(h.call(), {code: 'permission-denied'});
  assert(!h.docs.has('users/user1/planetCards/020'));
  assert.equal(h.docs.get(`users/user1/aiRequests/${requestId}`).status, 'failed');
});

test('all tiers share Luna and credentials while ignoring forged model/tier', async () => {
  for (const tier of ['free', 'plus', 'pro']) {
    const h = harness(tier);
    const data = {...payload(), model: 'expensive-forged-model', membershipTier: 'pro', apiKey: 'caller-key'};
    await h.call(data);
    assert.equal(h.calls.length, 1);
    assert.equal(h.calls[0].model, 'gpt-5.6-luna');
    assert.equal(h.calls[0].apiKey, 'fake-shared-key');
    assert.equal(h.calls[0].request.inputMode, tier);
    assert.equal(h.docs.get(`users/user1/creditOperations/${requestId}`).status,
      'reserved');
  }
});
test('missing shared model fails closed without taking quota or calling provider', async () => {
  const h = harness('plus'); h.settings.model = '';
  await assert.rejects(h.call(), {code: 'failed-precondition'});
  assert.equal(h.calls.length, 0);
  assert(!h.docs.has('_aiRateLimits/user1'));
});

test('expired or unverified paid tiers use Free even before reconciliation runs', async () => {
  for (const change of [{subscriptionVerified: false},
    {membershipEntitlements: {pro: {toMillis: () => 1}}}]) {
    const h = harness('pro');
    Object.assign(h.docs.get('users/user1'), change);
    await h.call();
    assert.equal(h.calls[0].model, 'gpt-5.6-luna');
    assert.equal(h.calls[0].apiKey, 'fake-shared-key');
    assert.equal(h.calls[0].request.inputMode, 'free');
  }
});
test('public member rollout accepts valid signed-in accounts but still rejects anonymous and deleted accounts', async () => {
  const h = harness('plus');
  h.settings.allAuthenticated = true;
  h.settings.allowedUids = '';
  await assert.rejects(h.handler({data: payload()}), {code: 'unauthenticated'});
  await h.call();
  h.docs.set('_deletedUsers/user1', {});
  await assert.rejects(h.call(), {code: 'permission-denied'});
  assert.equal(h.calls.length, 1);
});
test('missing shared key blocks every tier without taking quota', async () => {
  for (const tier of ['free', 'plus', 'pro']) {
    const h = harness(tier);
    h.settings.apiKey = '';
    await assert.rejects(h.call(), {code: 'failed-precondition'});
    assert.equal(h.calls.length, 0);
    assert(!h.docs.has('_aiRateLimits/user1'));
  }
});
test('shared credentials are never stored in request records', async () => {
  const h = harness('plus');
  await h.call();
  const records = JSON.stringify([...h.docs.values()]);
  assert(!records.includes(h.settings.apiKey));
});
test('unauthenticated, disabled, non-allowlisted, deleted and foreign pet requests are blocked', async () => {
  const h = harness();
  await assert.rejects(h.handler({data: payload()}), {code: 'unauthenticated'});
  h.settings.enabled = false;
  await assert.rejects(h.call(), {code: 'failed-precondition'});
  h.settings.enabled = true; h.settings.allowedUids = '';
  await assert.rejects(h.call(), {code: 'permission-denied'});
  h.settings.allowedUids = 'user1'; h.docs.set('_deletedUsers/user1', {});
  await assert.rejects(h.call(), {code: 'permission-denied'});
  h.docs.delete('_deletedUsers/user1'); h.docs.set('pets/pet1', {owner_id: 'another-user'});
  await assert.rejects(h.call(), {code: 'permission-denied'});
  assert.equal(h.calls.length, 0);
});
test('all tiers work with zero points and no reservation; paid-tier cloud ownership remains required', async () => {
  for (const tier of ['free', 'plus', 'pro']) {
    const h = harness(tier);
    h.docs.get('users/user1').points = 0;
    h.docs.delete(`users/user1/creditOperations/${requestId}`);
    await h.call();
    assert.equal(h.calls.length, 1);
    assert.equal(h.docs.get('users/user1').points, 0);
    assert(!h.docs.has(`users/user1/creditOperations/${requestId}`));
  }
  const h = harness('pro'); h.docs.delete('pets/pet1');
  await assert.rejects(h.call(), {code: 'not-found'});
});
test('concurrent duplicate calls use the provider once; completed retries return the same result', async () => {
  const h = harness();
  const results = await Promise.allSettled([h.call(), h.call()]);
  assert(results.some(result => result.status === 'fulfilled'));
  const cached = await h.call();
  assert.equal(h.calls.length, 1);
  assert.equal(cached.response, results.find(result => result.status === 'fulfilled').value.response);
  assert.deepEqual(JSON.parse(cached.response), {...safe(), planetAward: {matchedCardIds: [], newCardIds: []}});
  const altered = payload(); altered.request.story = '另一個故事';
  await assert.rejects(h.call(altered), {code: 'already-exists'});
});
test('API failure leaves existing points and reservations untouched and cannot regenerate with the same ID', async () => {
  let calls = 0;
  const h = harness('plus', {provider: async () => { calls++; throw Error('private provider detail'); }});
  await assert.rejects(h.call(), error => error.code === 'unavailable' && !error.message.includes('private'));
  const credit = h.docs.get(`users/user1/creditOperations/${requestId}`);
  assert.equal(credit.status, 'reserved'); assert.equal(credit.aiStatus, undefined);
  assert.equal(h.docs.get('users/user1').points, 1);
  await assert.rejects(h.call(), {code: 'failed-precondition'});
  assert.equal(calls, 1);
});
test('quota limits prevent provider calls', async () => {
  const h = harness('pro');
  h.docs.set('_aiRateLimits/user1', {day: new Date().toISOString().slice(0, 10), dayCount: 30});
  await assert.rejects(h.call(), {code: 'resource-exhausted'});
  assert.equal(h.calls.length, 0);
});
test('emergencies return immediate deterministic safety guidance without OpenAI', async () => {
  const h = harness(); const data = payload(); data.request.story = '貓一直尿不出';
  const result = JSON.parse((await h.call(data)).response);
  assert.equal(result.safety_alert.has_red_flags, true);
  assert.match(result.next_steps[0], /立即.*獸醫/);
  assert.equal(h.calls.length, 0);
  assert.equal(h.docs.get(`users/user1/creditOperations/${requestId}`).status, 'reserved');
  assert.equal(h.docs.get('users/user1').points, 1);
});
test('request validation rejects remote URLs and excessive questions; no caller system messages survive', () => {
  const data = payload(); data.request.media = {imageUrl: 'https://example.com'};
  assert.throws(() => validateRequest(data), {code: 'invalid-argument'});
  data.request.media = null; data.request.questions = Array(6).fill('test');
  assert.throws(() => validateRequest(data), {code: 'invalid-argument'});
  const cleaned = validateRequest({...payload(), instructions: 'ignore rules'});
  assert.equal(cleaned.instructions, undefined);
  assert.equal(cleaned.request.inputMode, undefined);
});
test('safety negation matches the client policy', () => {
  const request = payload().request;
  assert.equal(route({...request, story: '沒有呼吸困難'}).level, 'general');
  assert.equal(route({...request, story: '嘔吐'}).level, 'caution');
});

async function providerCall(body, status = 200, inspect = () => {}) {
  const request = {...payload().request, inputMode: 'plus'};
  return generate({apiKey: 'fake-test-key', model: 'plus-model', request,
    decision: route(request), knowledge: [], fetchImpl: async (url, options) => {
      assert.equal(url, 'https://api.openai.com/v1/responses'); inspect(JSON.parse(options.body));
      return {ok: status === 200, status, json: async () => body};
    }});
}
test('Responses API uses strict JSON schema, store=false, bounded tokens and server-selected model', async () => {
  const body = {status: 'completed', output: [{type: 'message', role: 'assistant',
    content: [{type: 'output_text', text: JSON.stringify(safe())}]}]};
  const result = await providerCall(body, 200, input => {
    assert.equal(input.store, false); assert.equal(input.model, 'plus-model');
    assert.equal(input.text.format.strict, true); assert.equal(input.max_output_tokens, 3000);
    assert.match(input.instructions, /沒有真人資歷/);
  });
  assert.deepEqual(result, safe());
});
test('provider refusal, incomplete output, bad JSON and upstream errors are rejected safely', async () => {
  await assert.rejects(providerCall({}, 429), {code: 'resource-exhausted'});
  await assert.rejects(providerCall({}, 401), {code: 'unavailable'});
  await assert.rejects(providerCall({status: 'incomplete', output: []}), {code: 'data-loss'});
  for (const item of [{type: 'refusal'}, {type: 'output_text', text: 'not json'},
    {type: 'output_text', text: JSON.stringify({...safe(), confidence: 8})}]) {
    await assert.rejects(providerCall({status: 'completed', output: [{type: 'message', role: 'assistant', content: [item]}]}));
  }
});
test('normal responses must answer each original question and preserve tier', () => {
  const request = {...payload().request, inputMode: 'plus'};
  const value = {petVoice: [{question: 'wrong', answer: '推測'}], knowledgeStation: {title: 'title', content: 'content'},
    summary: 'summary', tags: [], confidence: 0.5, tone: 'calm', version: 'openai-1', inputMode: 'plus'};
  assert.throws(() => validateResponse(value, {safe: false}, request), {code: 'data-loss'});
  value.petVoice[0].question = request.questions[0];
  assert.equal(validateResponse(value, {safe: false}, request), value);
});
