const {decryptIndex, searchIndex} = require('./knowledge_retrieval_logic');
const INDEX_URL = 'https://fir-project-tw.web.app/assets/assets/ai_logic/knowledge/rag_index.json';
let cachedIndex;
async function loadIndex() {
  if (cachedIndex) return cachedIndex;
  const response = await fetch(INDEX_URL, {
    headers: {"Accept": "text/plain, application/json"},
    signal: AbortSignal.timeout(10000),
  });
  if (!response.ok) throw new Error(`Knowledge index HTTP ${response.status}`);
  const ciphertext = await response.text();
  cachedIndex = decryptIndex(ciphertext, process.env.KB_ENCRYPTION_KEY || "");
  return cachedIndex;
}

// Internal retrieval for AI: callers cannot submit trusted knowledge snippets.
exports.searchKnowledge = async ({query, species, limit}) => {
  const index = await loadIndex();
  return searchIndex(index, {query, species, limit}).map(hit => ({
    title: hit.title,
    safety_level: hit.safetyLevel,
    content: hit.content.slice(0, 1400),
  }));
};
