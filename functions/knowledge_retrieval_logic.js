const crypto = require("crypto");

const QUERY_EXPANSIONS = new Map([
  ["一直叫", "吠叫 哀鳴"],
  ["沒有尿", "無尿 排尿 尿道阻塞"],
  ["尿不出", "無尿 排尿 尿道阻塞"],
  ["打架", "衝突 攻擊"],
  ["獨自在家", "獨處 分離困擾"],
  ["撿到", "拾食 物品"],
  ["老貓", "高齡貓"],
]);

function decryptIndex(ciphertext, keyBase64) {
  const key = Buffer.from(keyBase64, "base64");
  if (key.length !== 32) throw new Error("Invalid knowledge encryption key");

  const payload = Buffer.from(ciphertext.trim(), "base64");
  if (payload.length < 29) throw new Error("Invalid encrypted knowledge index");
  const nonce = payload.subarray(0, 12);
  const tag = payload.subarray(payload.length - 16);
  const encrypted = payload.subarray(12, payload.length - 16);
  const decipher = crypto.createDecipheriv("aes-256-gcm", key, nonce);
  decipher.setAuthTag(tag);
  const plain = Buffer.concat([decipher.update(encrypted), decipher.final()]);
  const index = JSON.parse(plain.toString("utf8"));
  validateIndex(index);
  return index;
}

function validateIndex(index) {
  if (!index || index.schema_version !== 1 ||
      !Array.isArray(index.chunks) ||
      typeof index.inverted_index !== "object") {
    throw new Error("Unsupported or incomplete knowledge index");
  }
  if (!index.stats || index.stats.chunk_count !== index.chunks.length) {
    throw new Error("Knowledge index statistics do not match chunks");
  }
}

function terms(input) {
  const text = input.toLowerCase();
  const result = new Set(text.match(/[a-z0-9][a-z0-9_-]+/g) || []);
  for (const match of text.matchAll(/[\u3400-\u4dbf\u4e00-\u9fff]+/g)) {
    const span = match[0];
    for (const size of [2, 3]) {
      for (let i = 0; i <= span.length - size; i++) {
        result.add(span.substring(i, i + size));
      }
    }
  }
  return result;
}

function searchIndex(index, {query, species = "", limit = 4}) {
  const expanded = [query, species];
  for (const [needle, addition] of QUERY_EXPANSIONS) {
    if (query.includes(needle)) expanded.push(addition);
  }
  const queryTerms = terms(expanded.join(" "));
  const chunks = new Map(index.chunks.map((chunk) => [chunk.id, chunk]));
  const scores = new Map();

  for (const term of queryTerms) {
    const postings = index.inverted_index[term] || [];
    const weight = 1 + (1 / Math.max(postings.length, 1));
    for (const id of postings) scores.set(id, (scores.get(id) || 0) + weight);
  }

  const normalizedSpecies = species.toLowerCase();
  const isCat = normalizedSpecies.includes("貓") ||
    normalizedSpecies.includes("cat");
  const isDog = normalizedSpecies.includes("狗") ||
    normalizedSpecies.includes("犬") || normalizedSpecies.includes("dog");

  for (const [id, baseScore] of scores) {
    const chunk = chunks.get(id);
    if (!chunk) continue;
    const titleTerms = terms(chunk.title || "");
    let score = baseScore;
    for (const term of queryTerms) if (titleTerms.has(term)) score += 2;
    if ((chunk.tags || []).includes("P")) score += 3.5;
    if (isCat && chunk.document_id === "doc-006") score += 2;
    if (isDog && ["doc-004", "doc-005"].includes(chunk.document_id)) {
      score += 2;
    }
    scores.set(id, score);
  }

  return [...scores.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, Math.min(Math.max(limit, 1), 5))
    .map(([id, score]) => {
      const chunk = chunks.get(id);
      const source = chunk.source || {};
      return {
        id,
        documentId: chunk.document_id,
        sectionId: chunk.section_id,
        title: chunk.title,
        tags: chunk.tags || [],
        safetyLevel: chunk.safety_level,
        content: String(chunk.content || "").slice(0, 1400),
        sourcePath: "protected-knowledge",
        lineStart: Number(source.line_start || 0),
        lineEnd: Number(source.line_end || 0),
        score,
      };
    });
}

module.exports = {decryptIndex, searchIndex, validateIndex};
