const {createHash} = require('node:crypto');
const {readFile} = require('node:fs/promises');
const path = require('node:path');
const {decryptIndex, searchIndex} = require('./knowledge_retrieval_logic');

// A deployment uses one immutable encrypted index. Remote overrides must pin
// the exact ciphertext hash; a URL alone cannot silently change knowledge.
function createIndexLoader({env = process.env, fetcher = fetch, read = readFile,
  decrypt = decryptIndex} = {}) {
  let cachedIdentity, pending;
  return async () => {
    const url = env.KB_INDEX_URL;
    let sha256 = env.KB_INDEX_SHA256;
    if (url) {
      const target = new URL(url);
      if (target.protocol !== 'https:' || target.username || target.password) {
        throw new Error('Knowledge index requires an HTTPS URL without credentials');
      }
    } else {
      if (sha256) throw new Error('KB_INDEX_SHA256 requires KB_INDEX_URL');
      const manifest = JSON.parse(await read(path.join(__dirname, 'knowledge/manifest.json'), 'utf8'));
      sha256 = manifest.sha256;
    }
    if (!/^[a-f0-9]{64}$/.test(sha256 || '')) throw new Error('Knowledge index requires SHA-256');
    const key = env.KB_ENCRYPTION_KEY || '';
    const identity = JSON.stringify([url || 'bundled', sha256, key]);
    if (identity !== cachedIdentity) {
      cachedIdentity = identity;
      pending = (async () => {
        let bytes;
        if (url) {
          const response = await fetcher(url, {signal: AbortSignal.timeout(10000)});
          if (!response.ok) throw new Error(`Knowledge index HTTP ${response.status}`);
          bytes = Buffer.from(await response.arrayBuffer());
        } else {
          bytes = await read(path.join(__dirname, 'knowledge/rag_index.enc'));
        }
        if (createHash('sha256').update(bytes).digest('hex') !== sha256) {
          throw new Error('Knowledge index integrity mismatch');
        }
        return decrypt(bytes.toString('utf8'), key);
      })();
    }
    const active = pending;
    try { return await active; } catch (error) {
      if (pending === active) { cachedIdentity = undefined; pending = undefined; }
      throw error;
    }
  };
}
const loadIndex = createIndexLoader();
exports.createIndexLoader = createIndexLoader;

// Internal retrieval for AI: callers cannot submit trusted knowledge snippets.
exports.searchKnowledge = async ({query, species, limit}) => {
  const index = await loadIndex();
  return searchIndex(index, {query, species, limit}).map(hit => ({
    title: hit.title,
    safety_level: hit.safetyLevel,
    content: hit.content.slice(0, 1400),
  }));
};
