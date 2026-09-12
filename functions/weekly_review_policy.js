const P = require('./journal_policy');
const {route} = require('./ai_contract');
const DAY = 86400000;
function weekRange(value, now) {
  const local = new Date(now + 8 * 3600000);
  const monday = Date.parse(`${P.dayKey(now)}T00:00:00+08:00`) - ((local.getUTCDay() + 6) % 7) * DAY;
  const start = value == null ? monday - 7 * DAY : Date.parse(`${value}T00:00:00+08:00`);
  if (!Number.isFinite(start) || (value != null && (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value) || P.dayKey(start) !== value)) ||
      start < 0 || start >= monday || new Date(start + 8 * 3600000).getUTCDay() !== 1) {
    P.fail('invalid-argument', '請選擇已結束的週一至週日');
  }
  return {week: P.dayKey(start), start, end: start + 7 * DAY};
}
function prepare(entries, species) {
  const texts = entries.filter(e => [e.observation, e.action, e.outcome].some(v => v?.trim()));
  const stats = {entries: entries.length, textDays: new Set(texts.map(e => P.dayKey(e.occurredAtMs))).size,
    days: new Set(entries.map(e => P.dayKey(e.occurredAtMs))).size};
  // Cover distinct dates first. Include only complete entries and account for JSON overhead.
  const first = [], rest = [], dates = new Set();
  for (const e of texts) {
    const day = P.dayKey(e.occurredAtMs);
    (dates.has(day) ? rest : first).push(e); dates.add(day);
  }
  const sources = [];
  for (const e of [...first, ...rest]) {
    const row = {entryId: e.id, revision: e.revision, date: P.dayKey(e.occurredAtMs),
      context: e.context, observation: e.observation, action: e.action, outcome: e.outcome};
    if (JSON.stringify({species, entries: [...sources, row]}).length <= 16000) sources.push(row);
  }
  const decision = route({story: texts.map(e => `${e.observation}\n${e.action}\n${e.outcome}`).join('\n'),
    questions: [], petProfile: {species}});
  return {stats, sources, decision, input: {species, entries: sources}};
}
const string = {type: 'string'};
const object = properties => ({type: 'object', properties, required: Object.keys(properties), additionalProperties: false});
const item = object({text: string, entryIds: {type: 'array', items: string, minItems: 1, maxItems: 5}});
const schema = object({happenings: {type: 'array', items: item, minItems: 1, maxItems: 4},
  observations: {type: 'array', items: item, minItems: 1, maxItems: 4},
  tips: {type: 'array', items: item, maxItems: 3}, petVoice: string});
function validateResult(value, sources) {
  const fail = () => P.fail('data-loss', '回顧格式或引用不正確，請稍後重試');
  if (!value || Object.keys(value).sort().join() !== 'happenings,observations,petVoice,tips') fail();
  const ids = new Set(sources.map(s => s.entryId));
  for (const [key, max] of [['happenings', 4], ['observations', 4], ['tips', 3]]) {
    if (!Array.isArray(value[key]) || value[key].length > max || (key !== 'tips' && !value[key].length)) fail();
    for (const row of value[key]) {
      if (!row || Object.keys(row).sort().join() !== 'entryIds,text' || typeof row.text !== 'string' || !row.text.trim() || row.text.length > 500 ||
          !Array.isArray(row.entryIds) || !row.entryIds.length || row.entryIds.length > 5 || new Set(row.entryIds).size !== row.entryIds.length || row.entryIds.some(id => !ids.has(id))) fail();
    }
  }
  if (typeof value.petVoice !== 'string' || value.petVoice.length > 300) fail();
  return value;
}
module.exports = {weekRange, prepare, schema, validateResult};
