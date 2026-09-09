// Conservative, deterministic matching of the returned knowledge, never user text.
// Each rule requires a subject AND its specific care concept within one sentence.
const rules = [
  ['001', /靠近|接近/, /自願|主動|等待|選擇/],
  ['002', /抓柱|抓板|抓面/, /伸展|伸懶腰|穩固/],
  ['003', /藏身|躲藏處|休息區|小角落/, /安靜|不被打擾|安全/],
  ['004', /外出籠/, /熟悉|自願|漸進|適應/],
  ['005', /玩具/, /手腳.{0,10}(不|別)|不.{0,10}手腳|取代手腳/],
  ['006', /食物|食碗|餐桌|進食|餵食/, /分散|分開|各自/],
  ['007', /階梯|台階|踏階/, /穩固|防滑|低|容易/],
  ['008', /貓砂|砂盆/, /每天.{0,10}(清|鏟)|每日.{0,10}(清|鏟)/],
  ['009', /獎勵|鼓勵/, /自願|及時|適時|小步/],
  ['010', /甩尾|尾巴甩|耳後移|轉頭盯手/, /停|暫停/],
  ['011', /新貓|引介|隔障|交換氣味/, /漸進|分隔|逐步|慢慢/],
  ['012', /照護者|探視|看望/, /每日|每天|過夜/],
  ['013', /窗/, /防逃|圍護|牢固|防護/],
  ['014', /橡皮筋|牙線|針|藥品/, /收好|收妥|收納|收起/],
  ['015', /記錄|紀錄/, /飲水|排泄|體重|進食|活動/],
  ['016', /孩子|兒童/, /成人|監督|引導/],
  ['017', /尋食|找食|找點心/, /安全|難度|簡單|容易/],
  ['018', /砂盆/, /轉身|1\.5|一點五|尺寸|大小合適/],
  ['019', /線繩玩具|逗貓棒/, /收妥|收起|收納|收好/],
  ['020', /翻肚|露肚/, /不代表|不等於|不是|不表示/],
];

function matchPlanetCards(value, species, level) {
  if (!/^(cat|貓|貓咪)$/i.test(species.trim()) || level === 'emergency' ||
      value.safety_alert?.has_red_flags === true) return [];
  const sections = value.knowledgeStation ? [value.knowledgeStation.content] : value.knowledge_tips;
  if (!Array.isArray(sections)) return [];
  const sentences = sections.filter(s => typeof s === 'string')
    .flatMap(s => s.split(/[。！？\n]/));
  return rules.filter(([, subject, concept]) => sentences.some(s => subject.test(s) && concept.test(s)))
    .map(([id]) => id);
}

module.exports = {matchPlanetCards};
