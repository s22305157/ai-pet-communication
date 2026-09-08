const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const test = require("node:test");
const {
  decryptIndex,
  searchIndex,
} = require("../knowledge_retrieval_logic");

const index = {
  schema_version: 1,
  stats: {chunk_count: 1},
  chunks: [{
    id: "urinary",
    document_id: "doc-006",
    section_id: "urinary",
    title: "貓咪排尿紅旗",
    tags: ["P"],
    safety_level: "red_flag",
    content: "無尿可能是尿道阻塞，應立即聯絡獸醫。",
    source: {line_start: 1, line_end: 2},
  }],
  inverted_index: {
    "無尿": ["urinary"],
    "排尿": ["urinary"],
    "尿道": ["urinary"],
    "阻塞": ["urinary"],
  },
};

function encrypt(value, key) {
  const nonce = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", key, nonce);
  const encrypted = Buffer.concat([
    cipher.update(Buffer.from(JSON.stringify(value))),
    cipher.final(),
  ]);
  return Buffer.concat([nonce, encrypted, cipher.getAuthTag()])
    .toString("base64");
}

test("decrypts an AES-GCM protected index", () => {
  const key = crypto.randomBytes(32);
  const decoded = decryptIndex(encrypt(index, key), key.toString("base64"));
  assert.equal(decoded.chunks[0].id, "urinary");
});

test("returns only limited matching knowledge excerpts", () => {
  const hits = searchIndex(index, {
    query: "貓咪一直用力但沒有尿",
    species: "貓",
    limit: 9,
  });
  assert.equal(hits.length, 1);
  assert.equal(hits[0].id, "urinary");
  assert.equal(hits[0].sourcePath, "protected-knowledge");
  assert.match(hits[0].content, /尿道阻塞/);
});
