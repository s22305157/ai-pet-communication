const test = require('node:test');
const assert = require('node:assert/strict');
const {matchPlanetCards} = require('../planet_cards');
const examples = [
  "用鼻子觸碰目標物就給獎勵，不把目標物戳向貓咪。",
  "叫名字後貓咪看向你就給獎勵，不用提高音量催促。",
  "墊上練習從踩到墊面開始，再逐步增加停留時間。",
  "依貓咪偏好選獎勵，不把每隻貓都當成愛吃點心。",
  "搬運外出籠時托住底部，保持水平並減少晃動。",
  "看診返家的貓若引起同伴緊張，先分室休息再重聚。",
  "撫摸幾下就停手，觀察貓咪是否還想互動。",
  "貓咪發出嘶聲時先退開，不模仿嘶聲或責罵。",
  "瞳孔大小也受光線影響，不能只憑瞳孔判斷情緒。",
  "豎尾配合放鬆姿勢常是友善訊號，仍要看整體情境。",
  "追逐若總是一方逃躲，應中止互動並評估壓力。",
  "抓板可放在常抓的家具旁，提供就近替代位置。",
  "食碗用後清洗並充分沖淨，避免殘留舊食與清潔劑。",
  "可提供寵物飲水機，觀察貓咪是否偏好流動的水。",
  "可試寬口淺碗，依貓咪實際使用情形調整。",
  "多貓家庭提供足夠床位，讓貓咪能分散休息。",
  "外出時帶上有熟悉氣味的小毯，減少環境陌生感。",
  "窗簾拉繩固定在貓咪碰不到處，避免繩圈纏繞。",
  "炎熱時提供陰涼通風處與清水，讓貓咪能避開日曬。",
  "紙箱先去除膠帶與釘針，保留可自由進出的開口。"
];

test('cat cards 121-140 map to exactly their own captions in both response formats', () => {
 examples.forEach((content,i) => {
  for (const value of [{knowledgeStation:{content}}, {knowledge_tips:[content]}])
   assert.deepEqual(matchPlanetCards(value,'cat','general'),[String(121+i)],content);
 });
});
test('cat 121-140 awards preserve aliases, deduplication, safety and trusted knowledge boundaries', () => {
 const ids=examples.map((_,i)=>String(121+i));
 const value={knowledge_tips:[...examples,...examples]};
 for(const species of ['cat','CAT',' 貓 ','貓咪'])
  assert.deepEqual(matchPlanetCards(value,species,'general'),ids);
 for(const species of ['dog','狗','狗狗','犬','犬隻','rabbit','catfish'])
  assert(matchPlanetCards(value,species,'general').every(id=>Number(id)<121));
 assert.deepEqual(matchPlanetCards(value,'cat','emergency'),[]);
 assert.deepEqual(matchPlanetCards({...value,safety_alert:{has_red_flags:true}},'cat','caution'),[]);
 assert.deepEqual(matchPlanetCards({petVoice:examples,tags:examples,cardIds:ids},'cat','general'),[]);
 assert.deepEqual(matchPlanetCards({knowledgeStation:{content:'今天很好'},knowledge_tips:examples},'cat','general'),[]);
 for(const content of ['談談瞳孔。另一件事與光線有關。','提到食碗。需要用後清洗。','談談窗簾拉繩。請固定物品。','今天有紙箱與飲水機','討論撫摸與叫名字'])
  assert.deepEqual(matchPlanetCards({knowledge_tips:[content]},'cat','general'),[],content);
});
