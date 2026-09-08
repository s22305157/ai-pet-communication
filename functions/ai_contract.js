const {HttpsError} = require('firebase-functions/v2/https');
const {validateRequestId, validatePetId} = require('./credit_logic');

const string = {type: 'string', minLength: 1, maxLength: 4000};
const strings = {type: 'array', items: string, maxItems: 10};
const tone = {type: 'string', enum: ['warm', 'gentle', 'calm', 'encouraging']};
const object = properties => ({type: 'object', properties,
  required: Object.keys(properties), additionalProperties: false});
const confidence = {type: 'number', minimum: 0, maximum: 1};
const standardSchema = object({
  petVoice: {type: 'array', minItems: 1, maxItems: 5,
    items: object({question: string, answer: string})},
  knowledgeStation: object({title: string, content: string}),
  summary: string, tags: strings, confidence, tone,
  version: {type: 'string', enum: ['openai-1']},
  inputMode: {type: 'string', enum: ['free', 'plus', 'pro']},
});
const safeSchema = object({
  version: {type: 'string', enum: ['openai-safe-1']},
  mode: {type: 'string', enum: ['safe_default']}, disclaimer: string,
  pet_voice: object({text: string,
    tone: {type: 'string', enum: ['gentle', 'calm', 'supportive', 'neutral']},
    is_inference: {type: 'boolean', enum: [true]}}),
  knowledge_tips: strings,
  safety_alert: object({has_red_flags: {type: 'boolean'},
    message: string, red_flags: strings}),
  next_steps: {...strings, minItems: 1}, confidence,
  needs_more_info: {type: 'boolean'}, missing_info: strings, tags: strings,
});

function text(value, name, limit, empty = false) {
  if (typeof value !== 'string' || value.length > limit || (!empty && !value.trim())) {
    throw new HttpsError('invalid-argument', `Invalid ${name}`);
  }
  return value.trim();
}

function validateRequest(data) {
  if (!data || typeof data !== 'object' || Array.isArray(data) ||
      Buffer.byteLength(JSON.stringify(data)) > 32000) {
    throw new HttpsError('invalid-argument', 'Invalid AI request');
  }
  const requestId = validateRequestId(data.requestId);
  const petId = validatePetId(data.petId);
  const source = data.request;
  if (!source || !source.ownerProfile || !source.petProfile ||
      !Array.isArray(source.questions) || source.questions.length < 1 || source.questions.length > 5) {
    throw new HttpsError('invalid-argument', 'Invalid consultation');
  }
  if (source.media != null) {
    throw new HttpsError('failed-precondition', '目前僅開放文字 AI 溝通');
  }
  const ownerProfile = {};
  for (const key of ['experienceLevel', 'careStyle', 'emotionStyle', 'dailyRoutine', 'mainConcern']) {
    ownerProfile[key] = text(source.ownerProfile[key], key, 500, true);
  }
  const petProfile = {};
  for (const key of ['name', 'species', 'breed', 'coatColor']) {
    petProfile[key] = text(source.petProfile[key], key, 200, key !== 'name' && key !== 'species');
  }
  const age = source.petProfile.age;
  if (age !== null && (typeof age !== 'number' || !Number.isFinite(age) || age < 0 || age > 200)) {
    throw new HttpsError('invalid-argument', 'Invalid age');
  }
  const traits = source.petProfile.personalityTraits;
  if (!Array.isArray(traits) || traits.length > 10) {
    throw new HttpsError('invalid-argument', 'Invalid personality traits');
  }
  petProfile.age = age;
  petProfile.personalityTraits = traits.map(value => text(value, 'trait', 4000, true));
  return {requestId, petId, request: {ownerProfile, petProfile,
    story: text(source.story, 'story', 5000),
    questions: source.questions.map(value => text(value, 'question', 500)),
    media: null}};
}

// Mirrors the app router. Server decisions cannot be supplied by the caller.
const rules = [
  ['breathing_emergency', /呼吸困難|呼吸急促|無法呼吸|張口呼吸|嘴巴呼吸|發紺|舌頭.*(藍|紫)/g],
  ['neurologic_emergency', /抽搐|昏迷|失去意識|叫不醒|無法站立/g],
  ['bleeding_emergency', /大出血|血流不止|持續出血/g],
  ['urinary_obstruction', /尿不出|沒有尿|無尿|一直[^。！？\n]{0,12}用力[^。！？\n]{0,8}尿|反覆[^。！？\n]{0,12}貓砂盆[^。！？\n]{0,8}(沒尿|無尿)/g, true],
  ['toxin_or_foreign_body', /(吃到|舔到|誤食|吞下)[^。！？\n]{0,12}(百合|人藥|清潔劑|殺蟲劑|毒物|針|牙線|線|繩)/g],
  ['major_trauma', /被車撞|遭車撞|墜樓|高處墜落/g],
];
function hasMatch(pattern, value) {
  return [...value.matchAll(pattern)].some(match =>
    !/(沒有|並無|未見|未出現|沒有出現)\s*$/.test(value.slice(Math.max(0, match.index - 6), match.index)));
}
function route(request) {
  const value = `${request.story} ${request.questions.join(' ')}`;
  const cat = /貓|cat/i.test(request.petProfile.species) || value.includes('貓');
  const matched = rules.filter(([, pattern, catsOnly]) => (!catsOnly || cat) && hasMatch(pattern, value)).map(([id]) => id);
  const caution = hasMatch(/嘔吐|腹瀉|血尿|血便|疼痛|嗜睡|拒食|不吃東西|傷口|突然攻擊|突然咬人/g, value);
  return {level: matched.length ? 'emergency' : caution ? 'caution' : 'general',
    safe: matched.length > 0 || caution || request.story.length < 300, matched};
}

function validateSchema(value, schema) {
  const invalid = () => { throw new HttpsError('data-loss', 'AI 回應格式不完整，請稍後再試'); };
  if (schema.enum && !schema.enum.includes(value)) invalid();
  if (schema.type === 'object') {
    if (!value || typeof value !== 'object' || Array.isArray(value)) invalid();
    if (Object.keys(value).length !== schema.required.length || schema.required.some(key => !(key in value))) invalid();
    for (const key of schema.required) validateSchema(value[key], schema.properties[key]);
  } else if (schema.type === 'array') {
    if (!Array.isArray(value) || value.length < (schema.minItems || 0) || value.length > schema.maxItems) invalid();
    value.forEach(item => validateSchema(item, schema.items));
  } else if (typeof value !== schema.type) invalid();
  else if (schema.type === 'string' && (!value.trim() || value.length > (schema.maxLength || 4000))) invalid();
  else if (schema.type === 'number' && (!Number.isFinite(value) || value < schema.minimum || value > schema.maximum)) invalid();
}

function validateResponse(value, decision, request) {
  validateSchema(value, decision.safe ? safeSchema : standardSchema);
  if (decision.safe && value.safety_alert.has_red_flags && !value.safety_alert.red_flags.length) {
    throw new HttpsError('data-loss', 'AI 安全提醒不完整');
  }
  if (!decision.safe && (value.inputMode !== request.inputMode || value.petVoice.length !== request.questions.length ||
      value.petVoice.some((item, i) => item.question !== request.questions[i]))) {
    throw new HttpsError('data-loss', 'AI 回應未完整對應問題');
  }
  return value;
}

function emergencyResponse(decision) {
  const labels = {breathing_emergency: '呼吸警訊', neurologic_emergency: '意識或神經症狀',
    bleeding_emergency: '持續出血', urinary_obstruction: '排尿困難',
    toxin_or_foreign_body: '疑似接觸毒物或吞入異物', major_trauma: '重大外傷'};
  return {version: 'openai-safe-1', mode: 'safe_default',
    disclaimer: '這是根據您描述的風險提供的安全提醒，並非醫療診斷或寵物心念讀取。',
    pet_voice: {text: '目前應優先確認毛孩的身體安全，暫不進行想像式心語。', tone: 'calm', is_inference: true},
    knowledge_tips: ['請向獸醫描述症狀、發生時間與可能接觸的物品。'],
    safety_alert: {has_red_flags: true, message: '描述中有需要立即處理的警訊。', red_flags: decision.matched.map(id => labels[id] || '安全警訊')},
    next_steps: ['立即聯絡獸醫或動物急診，不要等待 AI 溝通結果。'], confidence: 0,
    needs_more_info: false, missing_info: [], tags: ['安全提醒']};
}

module.exports = {validateRequest, route, validateResponse, emergencyResponse, standardSchema, safeSchema};
