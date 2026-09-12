const test = require('node:test');
const assert = require('node:assert/strict');
const {matchPlanetCards} = require('../planet_cards');
const examples = [
  "在墊子上安定放鬆時給獎勵，慢慢延長時間。",
  "迎接時獎勵四腳著地，不推撞或用膝蓋頂狗狗。",
  "鼻碰手練習由狗狗主動觸碰，不把手壓向鼻子。",
  "叫名字後狗狗轉頭看你就獎勵，避免連續喊叫。",
  "等待練習從短時間開始，用解除口令結束。",
  "訓練採短場次，疲累或分心時先休息。",
  "家人使用一致口令與手勢，避免同時下指令。",
  "新動作先在安靜少干擾的室內練習。",
  "換到新地點練習時降低難度，再逐漸增加干擾。",
  "依狗狗偏好選擇食物、玩具或稱讚作為獎勵。",
  "玩具依材質清潔，充分沖洗並乾燥後再給狗狗。",
  "多犬家庭提供足夠床位，避免爭搶休息位置。",
  "庭院活動前檢查圍欄與大門，避免縫隙逃脫。",
  "運動量依年齡、健康與體力調整，不一味加量。",
  "建立可預期的日常作息，保留吃飯、活動與休息時間。",
  "出門前先繫妥牽繩，在門口練習停等再通行。",
  "先從關機的吸塵器開始熟悉，不追著狗狗吸。",
  "用固定標記詞指出做對的瞬間，接著給獎勵。",
  "嘴套練習讓狗狗自願探入，初期不扣住或強戴。",
  "收玩具練習從籃子旁開始，放入就給獎勵。"
];
test('dog cards 101-120 each match exactly their own caption in both response formats', () => {
 examples.forEach((content,i) => {
  for (const value of [{knowledgeStation:{content}}, {knowledge_tips:[content]}]) {
   assert.deepEqual(matchPlanetCards(value,'dog','general'),[String(101+i)],content);
  }
 });
});
test('new dog awards preserve species, trusted fields, deduplication and emergency gate', () => {
 const value={knowledge_tips:[...examples,...examples]};
 const ids=examples.map((_,i)=>String(101+i));
 for(const species of ['dog','DOG',' 狗 ','狗狗','犬','犬隻'])
  assert.deepEqual(matchPlanetCards(value,species,'general'),ids);
 for(const species of ['cat','貓','貓咪','rabbit','hotdog',''])
  assert(matchPlanetCards(value,species,'general').every(id=>Number(id)<101));
 assert.deepEqual(matchPlanetCards(value,'dog','emergency'),[]);
 assert.deepEqual(matchPlanetCards({...value,safety_alert:{has_red_flags:true}},'dog','caution'),[]);
 assert.deepEqual(matchPlanetCards({petVoice:examples,cardIds:ids},'dog','general'),[]);
 assert.deepEqual(matchPlanetCards({knowledgeStation:{content:'今天好開心'},knowledge_tips:examples},'dog','general'),[]);
 for(const content of ['談談嘴套。可以自願探入。','名字與嘴套都很可愛','談談收玩具。籃子在角落。','訓練場地很寬敞','在門口看看風景'])
  assert.deepEqual(matchPlanetCards({knowledge_tips:[content]},'dog','general'),[],content);
});
