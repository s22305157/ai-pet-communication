const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {decryptIndex, searchIndex} = require("./knowledge_retrieval_logic");

const INDEX_URL = "https://fir-project-tw.web.app/assets/assets/" +
  "ai_logic/knowledge/rag_index.json";
const RATE_LIMIT_WINDOW_MS = 60 * 1000;
const RATE_LIMIT_REQUESTS = 20;
let cachedIndex;

function requireText(value, name, maxLength, allowEmpty = false) {
  if (typeof value !== "string" || value.length > maxLength ||
      (!allowEmpty && !value.trim())) {
    throw new HttpsError("invalid-argument", `Invalid ${name}`);
  }
  return value.trim();
}

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

async function consumeQuota(uid) {
  const ref = getFirestore().collection("_knowledgeRateLimits").doc(uid);
  const now = Date.now();
  await getFirestore().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data() || {};
    const current = typeof data.windowStartMs === "number" &&
      now - data.windowStartMs < RATE_LIMIT_WINDOW_MS;
    const count = current ? Number(data.count || 0) : 0;
    if (count >= RATE_LIMIT_REQUESTS) {
      throw new HttpsError("resource-exhausted", "Knowledge request limit reached");
    }
    transaction.set(ref, {
      windowStartMs: current ? data.windowStartMs : now,
      count: count + 1,
      expiresAt: Timestamp.fromMillis(now + RATE_LIMIT_WINDOW_MS * 2),
    });
  });
}

exports.retrieveKnowledge = onCall({
  maxInstances: 20,
  timeoutSeconds: 15,
  secrets: ["KB_ENCRYPTION_KEY"],
}, async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication required");
  }
  const query = requireText(request.data && request.data.query, "query", 2000);
  const species = requireText(
    (request.data && request.data.species) || "",
    "species",
    80,
    true,
  );
  const requestedLimit = Number(request.data && request.data.limit);
  const limit = Number.isInteger(requestedLimit) ? requestedLimit : 4;

  try {
    await consumeQuota(request.auth.uid);
    const index = await loadIndex();
    return {hits: searchIndex(index, {query, species, limit})};
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("Knowledge retrieval failed", {message: error.message});
    throw new HttpsError("internal", "Knowledge retrieval failed");
  }
});

// Internal retrieval for AI: callers cannot submit trusted knowledge snippets.
exports.searchKnowledge = async ({query, species, limit}) => {
  const index = await loadIndex();
  return searchIndex(index, {query, species, limit}).map(hit => ({
    title: hit.title,
    safety_level: hit.safetyLevel,
    content: hit.content.slice(0, 1400),
  }));
};
