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
const dogExamples = [
  '散步保留安全嗅聞時間，不急著拉走狗狗。',
  '獎勵牽繩放鬆時的同行，不用猛拉牽繩。',
  '遇到刺激先拉開距離，讓狗狗能放鬆再練習。',
  '在安全範圍練習召回，回到身邊就給獎勵。',
  '把練習拆成小步驟，及時獎勵自願的動作。',
  '讓狗狗自願接近陌生人，不強迫伸手撫摸。',
  '提供能自由進出的安心空間，不追入打擾。',
  '雷雨時提供安靜躲藏處，依狗狗需要陪伴。',
  '從不引起緊張的門鈴聲開始，搭配愉快經驗。',
  '從能放鬆的短暫分開開始，依反應調整時間。',
  '擦腳練習拆成小步驟，讓狗狗能選擇暫停。',
  '多犬用餐分開安排，避免靠近搶食或打擾。',
  '用合適獎勵練習交換，不追逐或硬搶物品。',
  '垃圾與易吞小物妥善收納，減少翻找誤食。',
  '用安全玩具引導啃咬，不拿手腳陪狗狗玩咬。',
  '孩子與狗狗互動由成人監督，不追抱或貼臉。',
  '從靜止車輛逐步熟悉，上路前妥善固定。',
  '提供安全簡單的尋食活動，依反應調整難度。',
  '記錄排泄時機，帶到合適地點並及時獎勵。',
  '提供穩固防滑的階梯，配合狗狗的行動能力。'
];

const nextCatExamples = [
  '在不同位置提供清水，水碗遠離食物與砂盆。',
  '設置穩固的高處平台，保留安全上下的路線。',
  '提供不同方向與材質的抓面，觀察貓咪偏好。',
  '紙袋先移除提把與繩線，再陪貓咪安全探索。',
  '維持可預期的餵食與陪伴，調整作息時循序漸進。',
  '寢具分批清洗，保留熟悉氣味，避免濃烈香氛。',
  '砂盆放在安靜易達處，避開吵雜設備與死角。',
  '更換貓砂時保留原有選擇，觀察接受度再調整。',
  '梳毛從短時間開始，出現不適就暫停，不拉扯毛結。',
  '候診時可遮蓋外出籠，保持通風並遠離犬隻。',
  '新食物少量提供，逐步轉換，留意食慾與排便。',
  '安排短場次遊戲，依貓咪興趣與體力調整。',
  '定期輪替安全玩具，檢查破損並更換不安全的玩具。',
  '抱持時支撐胸腹與後軀，不抓頸皮或懸吊四肢。',
  '呼嚕不一定代表開心，要搭配姿勢與當下情境觀察。',
  '異常排泄先找原因，突然改變應就醫，不用責罵處理。',
  '多貓動線保留繞行與退路，避免入口被另一隻貓堵住。',
  '行動不便的貓可用低入口砂盆，放在容易到達的位置。',
  '牛奶不是貓咪必需品，日常飲水以乾淨清水為主。',
  '百合花、花粉與花瓶水都可能危害貓咪，避免帶入家中。',
];

const nextDogExamples = [
  '隨時提供乾淨飲水，不為了少尿而限制喝水。',
  '零食計入每日總熱量，以少量獎勵取代額外加餐。',
  '吃太快可試合適慢食碗，觀察是否挫折或咬碗。',
  '胸背帶依體型調整，檢查磨擦、鬆脫與活動空間。',
  '多犬步調不同時可分開散步，配合各自需求。',
  '遇見別犬不必每次打招呼，保留距離與離開的選擇。',
  '搖尾不一定代表友善，要搭配姿勢與情境判斷。',
  '狗狗低吼時先停止逼近，不責罵，再評估原因。',
  '拉扯遊戲保持低位與短暫休息，不把狗狗吊離地面。',
  '睡覺時避免突然觸碰，讓狗狗自然醒來再互動。',
  '用影像觀察獨處反應，出現持續焦慮就調整照護。',
  '來客前安排安全分區，避免狗狗直接衝向門口。',
  '有追逐風險時分隔小動物，不放任狗狗追趕練習。',
  '在常走動線鋪穩固防滑墊，避免滑動與翹起的邊角。',
  '先讓狗狗熟悉梳具，短時間輕梳，避免硬扯毛結。',
  '刷牙循序適應，使用犬用牙膏，不用人用牙膏。',
  '洗澡先鋪防滑墊，水流避開眼耳，依反應暫停。',
  '外出即時清理狗狗糞便，處理後記得洗手。',
  '散步留意地面食物，提早繞開，不讓狗狗反覆撿食。',
  '安排安全的挖掘區，使用合適材料並在旁監督。',
];

const thirdCatExamples = [
  '可用慢眨眼回應貓咪，避免長時間直盯雙眼。',
  '踩奶延續幼貓時期的動作，可提供柔軟毯子承接。',
  '臉頰磨蹭會留下氣味標記，是貓咪常見的溝通方式。',
  '鬍鬚協助感知周遭，不修剪、拔除或拉扯鬍鬚。',
  '貓咪常在清晨與黃昏較活躍，可安排合適的互動活動。',
  '貓薄荷反應因貓而異，沒反應也正常，不必強迫使用。',
  '砂盆以貓數加一為起點，分布在不同位置而非並排。',
  '有蓋或開放式砂盆各有偏好，可提供選擇並觀察使用。',
  '貓砂優先選無香味款，不用香粉掩蓋髒污。',
  '若佩戴項圈，選可快解款並定期檢查鬆緊與磨擦。',
  '晶片登記的電話與地址有變更時，記得更新聯絡資料。',
  '搬家先安頓在備妥用品的房間，再依反應擴大探索。',
  '乘車時關妥並固定外出籠，不讓貓咪在車內自由走動。',
  '評估體態要看腰身並觸摸肋骨，長毛不能只靠外觀。',
  '用電子秤量好主食份量，再依體況與獸醫建議調整。',
  '用能抓住的實體玩具，避免只有追不到的光點。',
  '刷牙先循序適應，使用貓用牙膏，不用人用牙膏。',
  '剪指甲先適應碰腳，不確定剪哪裡就請專業示範。',
  '過度理毛或出現禿毛，先請獸醫排除身體問題。',
  '洗衣機、烘衣機啟動前先檢查滾筒，平時關好機門。',
];

test('cat cards 081 through 100 map to exactly their own card', () => {
  thirdCatExamples.forEach((content, i) => assert.deepEqual(
    matchPlanetCards({knowledgeStation: {content}}, '貓咪', 'general'),
    [String(i + 81).padStart(3, '0')], content));
});

test('third cat batch preserves species, safety, deduplication and trusted text boundaries', () => {
  const value = {knowledge_tips: [...examples, ...nextCatExamples, ...thirdCatExamples, ...thirdCatExamples]};
  for (const species of ['cat', 'CAT', ' 貓 ', '貓咪']) {
    assert.deepEqual(matchPlanetCards(value, species, 'general'),
      [...Array.from({length: 20}, (_, i) => String(i + 1).padStart(3, '0')),
        ...Array.from({length: 20}, (_, i) => String(i + 41).padStart(3, '0')),
        ...Array.from({length: 20}, (_, i) => String(i + 81).padStart(3, '0'))]);
  }
  assert(matchPlanetCards(value, 'dog', 'general').every(id =>
    (Number(id) >= 21 && Number(id) <= 40) || (Number(id) >= 61 && Number(id) <= 80)));
  assert.deepEqual(matchPlanetCards(value, 'cat', 'emergency'), []);
  assert.deepEqual(matchPlanetCards({...value, safety_alert: {has_red_flags: true}}, 'cat', 'caution'), []);
  assert.deepEqual(matchPlanetCards({petVoice: thirdCatExamples, cardIds: ['100']}, 'cat', 'general'), []);
  assert.deepEqual(matchPlanetCards({
    knowledgeStation: {content: '今天心情不錯'}, knowledge_tips: thirdCatExamples
  }, 'cat', 'general'), []);
  for (const content of ['談談晶片。記得更新聯絡資料。', '談談洗衣機。啟動前先檢查。',
    '談談鬍鬚。其他東西不修剪。', '今天聊項圈、砂盆和貓薄荷']) {
    assert.deepEqual(matchPlanetCards({knowledge_tips: [content]}, 'cat', 'general'), [], content);
  }
});

test('dog cards 061 through 080 map to exactly their own card', () => {
  nextDogExamples.forEach((content, i) => assert.deepEqual(
    matchPlanetCards({knowledgeStation: {content}}, '犬隻', 'general'),
    [String(i + 61).padStart(3, '0')], content));
});

test('new dog cards preserve species, safety, deduplication and trusted text boundaries', () => {
  const value = {knowledge_tips: [...dogExamples, ...nextDogExamples, ...nextDogExamples]};
  for (const species of ['dog', 'DOG', ' 狗狗 ', '狗', '犬', '犬隻']) {
    assert.deepEqual(matchPlanetCards(value, species, 'general'),
      [...Array.from({length: 20}, (_, i) => String(i + 21).padStart(3, '0')),
        ...Array.from({length: 20}, (_, i) => String(i + 61).padStart(3, '0'))]);
  }
  assert(matchPlanetCards(value, 'cat', 'general').every(id =>
    Number(id) <= 20 || (Number(id) >= 41 && Number(id) <= 60) ||
    (Number(id) >= 81 && Number(id) <= 100)));
  assert.deepEqual(matchPlanetCards(value, 'dog', 'emergency'), []);
  assert.deepEqual(matchPlanetCards({...value, safety_alert: {has_red_flags: true}}, 'dog', 'caution'), []);
  assert.deepEqual(matchPlanetCards({petVoice: nextDogExamples, cardIds: ['080']}, 'dog', 'general'), []);
  assert.deepEqual(matchPlanetCards({
    knowledgeStation: {content: '今天心情不錯'}, knowledge_tips: nextDogExamples
  }, 'dog', 'general'), []);
  for (const content of ['談談挖掘區。請注意安全。', '談談刷牙。犬用牙膏放在櫃子裡。',
    '談談狗狗低吼。另一件事要停止逼近。', '看到胸背帶與慢食碗', '今天有客人和小動物']) {
    assert.deepEqual(matchPlanetCards({knowledge_tips: [content]}, 'dog', 'general'), [], content);
  }
});

test('cat cards 041 through 060 map without accidentally awarding earlier cards', () => {
  nextCatExamples.forEach((content, i) => assert.deepEqual(
    matchPlanetCards({knowledgeStation: {content}}, '貓', 'general'),
    [String(i + 41).padStart(3, '0')], content));
});

test('new cat cards preserve species, emergency and returned-knowledge boundaries', () => {
  const value = {knowledge_tips: [...examples, ...nextCatExamples, ...nextCatExamples]};
  assert.deepEqual(matchPlanetCards(value, '貓咪', 'general'),
    [...Array.from({length: 20}, (_, i) => String(i + 1).padStart(3, '0')),
      ...Array.from({length: 20}, (_, i) => String(i + 41).padStart(3, '0'))]);
  assert(matchPlanetCards(value, 'dog', 'general').every(id => Number(id) >= 21 && Number(id) <= 40));
  assert.deepEqual(matchPlanetCards(value, 'cat', 'emergency'), []);
  assert.deepEqual(matchPlanetCards({...value, safety_alert: {has_red_flags: true}}, 'cat', 'caution'), []);
  assert.deepEqual(matchPlanetCards({petVoice: nextCatExamples, cardIds: ['060']}, 'cat', 'general'), []);
  assert.deepEqual(matchPlanetCards({knowledge_tips: ['談談紙袋。需要移除提把。']}, 'cat', 'general'), []);
});

test('all 20 dog knowledge captions map to their own card', () => {
  dogExamples.forEach((content, i) => assert.deepEqual(
    matchPlanetCards({knowledgeStation: {content}}, '狗', 'general'),
    [String(i + 21).padStart(3, '0')], content));
});

test('species aliases keep cat and dog award IDs separate', () => {
  const value = {knowledge_tips: [...examples, ...dogExamples]};
  for (const species of ['dog', 'DOG', ' 狗狗 ', '狗', '犬', '犬隻']) {
    assert.deepEqual(matchPlanetCards(value, species, 'general'),
      Array.from({length: 20}, (_, i) => String(i + 21).padStart(3, '0')));
  }
  for (const species of ['cat', '貓', '貓咪']) {
    assert.deepEqual(matchPlanetCards(value, species, 'general'),
      Array.from({length: 20}, (_, i) => String(i + 1).padStart(3, '0')));
  }
  for (const species of ['rabbit', 'hotdog', '貓狗', '', null, undefined, 42]) {
    assert.deepEqual(matchPlanetCards(value, species, 'general'), []);
  }
});

test('dog cards require returned knowledge and remain blocked for emergencies', () => {
  for (const value of [{}, {petVoice: dogExamples, tags: dogExamples},
    {cardIds: ['021'], planetAward: {matchedCardIds: ['021'], newCardIds: ['021']}},
    {knowledgeStation: {content: 21}}, {knowledge_tips: '散步保留安全嗅聞時間'}]) {
    assert.deepEqual(matchPlanetCards(value, 'dog', 'general'), []);
  }
  const value = {knowledge_tips: dogExamples};
  assert.deepEqual(matchPlanetCards(value, 'dog', 'emergency'), []);
  assert.deepEqual(matchPlanetCards({...value, safety_alert: {has_red_flags: true}}, 'dog', 'caution'), []);
  assert.deepEqual(matchPlanetCards({knowledge_tips: [dogExamples[0], dogExamples[0]]}, 'dog', 'caution'), ['021']);
  assert.deepEqual(matchPlanetCards({knowledge_tips: ['談談門鈴。另一件事需要漸進適應。']}, 'dog', 'general'), []);
  assert.deepEqual(matchPlanetCards({knowledge_tips: ['外出籠適應', '這個玩具容易使用']}, 'dog', 'general'), []);
});
test('all 20 knowledge concepts have deterministic mappings', () => {
  examples.forEach((content, i) => assert.deepEqual(
    matchPlanetCards({knowledgeStation: {content}}, '貓', 'general'),
    [String(i + 1).padStart(3, '0')], content));
});
test('safe tips match; unrelated voice, tags and missing knowledge do not', () => {
  assert.deepEqual(matchPlanetCards({knowledge_tips: [examples[19]]}, 'cat', 'caution'), ['020']);
  for (const value of [{}, {petVoice: examples, tags: examples},
    {knowledgeStation: {content: '今天玩得很開心'}}]) {
    assert.deepEqual(matchPlanetCards(value, 'cat', 'general'), []);
  }
  assert.deepEqual(matchPlanetCards({knowledge_tips: examples}, 'rabbit', 'general'), []);
  assert.deepEqual(matchPlanetCards({knowledge_tips: examples}, 'cat', 'emergency'), []);
  assert.deepEqual(matchPlanetCards({knowledge_tips: examples, safety_alert: {has_red_flags: true}}, 'cat', 'caution'), []);
});
test('repeated concepts deduplicate and subjects cannot match across sentences', () => {
  assert.deepEqual(matchPlanetCards({knowledge_tips: [examples[19], examples[19]]}, '貓', 'general'), ['020']);
  assert.deepEqual(matchPlanetCards({knowledge_tips: ['談談砂盆。選擇大小合適的玩具。']}, '貓', 'general'), []);
});
