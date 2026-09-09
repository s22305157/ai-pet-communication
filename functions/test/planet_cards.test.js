const test = require('node:test');
const assert = require('node:assert/strict');
const {matchPlanetCards} = require('../planet_cards');
const examples = [
  '等待貓咪主動靠近', '抓柱要穩固並能伸展', '提供不被打擾的休息區',
  '外出籠練習自願進入', '使用玩具，手腳不當獵物', '各自分開進食',
  '提供穩固階梯', '貓砂每天清除排泄物', '及時獎勵自願動作',
  '尾巴甩動就暫停', '新貓逐步引介', '照護者每日探視',
  '窗戶需要牢固防逃設施', '收好橡皮筋', '記錄飲水和排泄',
  '孩子互動由成人監督', '提供安全尋食活動', '砂盆讓貓輕鬆轉身',
  '線繩玩具用後收妥', '翻肚不代表同意摸肚子',
];
test('all 20 knowledge concepts have deterministic mappings', () => {
  examples.forEach((content, i) => assert.deepEqual(
    matchPlanetCards({knowledgeStation: {content}}, '貓', 'general'),
    [String(i + 1).padStart(3, '0')], content));
});
test('safe tips match; unrelated voice, tags, missing knowledge and dogs do not', () => {
  assert.deepEqual(matchPlanetCards({knowledge_tips: [examples[19]]}, 'cat', 'caution'), ['020']);
  for (const value of [{}, {petVoice: examples, tags: examples},
    {knowledgeStation: {content: '今天玩得很開心'}}]) {
    assert.deepEqual(matchPlanetCards(value, 'cat', 'general'), []);
  }
  assert.deepEqual(matchPlanetCards({knowledge_tips: examples}, 'dog', 'general'), []);
  assert.deepEqual(matchPlanetCards({knowledge_tips: examples}, 'cat', 'emergency'), []);
  assert.deepEqual(matchPlanetCards({knowledge_tips: examples, safety_alert: {has_red_flags: true}}, 'cat', 'caution'), []);
});
test('repeated concepts deduplicate and subjects cannot match across sentences', () => {
  assert.deepEqual(matchPlanetCards({knowledge_tips: [examples[19], examples[19]]}, '貓', 'general'), ['020']);
  assert.deepEqual(matchPlanetCards({knowledge_tips: ['談談砂盆。選擇大小合適的玩具。']}, '貓', 'general'), []);
});
