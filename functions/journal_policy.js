const {HttpsError} = require('firebase-functions/v2/https');
const LIMITS = Object.freeze({entries: 300, bytes: 200 * 1024 * 1024,
  inputBytes: 10 * 1024 * 1024, imageBytes: 1024 * 1024, dailyEntries: 20});
const CONTEXTS = ['環境適應', '飲食日常', '遊戲互動', '休息', '外出籠', '其他'];
const FOCUSES = ['新貓到家', '熟悉環境', '遊戲互動', '外出籠適應'];
const fail = (code, message) => { throw new HttpsError(code, message); };
const id = value => {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) fail('invalid-argument', '識別碼格式不正確');
  return value;
};
function text(value, max, required = false) {
  if (typeof value !== 'string' || value.length > max || (required && !value.trim())) fail('invalid-argument', '文字內容不符合限制');
  return value.trim();
}
function time(value, now) {
  if (!Number.isSafeInteger(value) || value < 0 || value > now) fail('invalid-argument', '日期不可晚於目前時間');
  return value;
}
const millis = value => value?.toMillis?.() || 0;
const dayKey = value => new Date(value + 8 * 3600000).toISOString().slice(0, 10);
function entryInput(data, now) {
  const observation = text(data.observation, 2000);
  const action = text(data.action, 500);
  const outcome = text(data.outcome, 500);
  if (!CONTEXTS.includes(data.context)) fail('invalid-argument', '請選擇有效情境');
  if (!Array.isArray(data.mediaIds) || data.mediaIds.length > 3 || new Set(data.mediaIds).size !== data.mediaIds.length) fail('invalid-argument', '每則最多三張不重複照片');
  const mediaIds = data.mediaIds.map(id);
  if (!observation && !action && !outcome && !mediaIds.length) fail('invalid-argument', '請加入文字或照片');
  if (!Number.isInteger(data.expectedRevision) || data.expectedRevision < 0) fail('invalid-argument', '缺少資料版本');
  return {observation, action, outcome, context: data.context, mediaIds, occurredAtMs: time(data.occurredAtMs, now)};
}
async function normalizeImage(bytes) {
  if (!Buffer.isBuffer(bytes) || bytes.length > LIMITS.inputBytes) fail('invalid-argument', '照片不得超過 10 MiB');
  const sharp = require('sharp');
  try {
    const image = sharp(bytes, {limitInputPixels: 40000000, animated: false, failOn: 'error'});
    const metadata = await image.metadata();
    if (!['jpeg', 'png'].includes(metadata.format) || (metadata.pages || 1) !== 1) fail('invalid-argument', '僅支援單張 JPEG 或 PNG');
    // Re-encoding strips metadata; do not use keepMetadata/withMetadata.
    for (const quality of [82, 65, 45, 25]) {
      const result = await image.clone().rotate().resize({width: 1600, height: 1600, fit: 'inside', withoutEnlargement: true})
          .flatten({background: '#ffffff'}).jpeg({quality, mozjpeg: true}).toBuffer();
      if (result.length <= LIMITS.imageBytes) return result;
    }
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    fail('invalid-argument', '無法讀取照片，請改用 JPEG 或 PNG');
  }
  fail('invalid-argument', '照片無法壓縮至 1 MiB');
}
module.exports = {LIMITS, CONTEXTS, FOCUSES, fail, id, text, time, millis, dayKey, entryInput, normalizeImage};
