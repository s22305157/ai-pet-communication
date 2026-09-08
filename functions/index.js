const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const creditOperations = require("./credit_operations");
const accountOperations = require("./account_operations");
const knowledgeRetrieval = require("./knowledge_retrieval");
const {
  TargetValidationError,
  parseAllowedTarget,
  assertPublicDns,
  hasAllowedImageSignature,
} = require("./proxy_security");

initializeApp();

const MAX_REDIRECTS = 3;
const MAX_RESPONSE_BYTES = 10 * 1024 * 1024;
const UPSTREAM_TIMEOUT_MS = 8000;
const RATE_LIMIT_WINDOW_MS = 60 * 1000;
const RATE_LIMIT_REQUESTS = 60;
const ALLOWED_IMAGE_TYPES = new Set(["image/jpeg", "image/png"]);

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

async function authenticate(req) {
  const match = (req.get("authorization") || "").match(/^Bearer (\S+)$/);
  if (!match) {
    throw new HttpError(401, "Authentication required");
  }

  try {
    return await getAuth().verifyIdToken(match[1]);
  } catch (_) {
    throw new HttpError(401, "Invalid authentication token");
  }
}

async function consumeQuota(uid) {
  const db = getFirestore();
  const ref = db.collection("_proxyRateLimits").doc(uid);
  const now = Date.now();

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data() || {};
    const inCurrentWindow =
      typeof data.windowStartMs === "number" &&
      now - data.windowStartMs < RATE_LIMIT_WINDOW_MS;
    const count = inCurrentWindow ? (data.count || 0) : 0;

    if (count >= RATE_LIMIT_REQUESTS) {
      throw new HttpError(429, "Image proxy rate limit exceeded");
    }

    transaction.set(ref, {
      windowStartMs: inCurrentWindow ? data.windowStartMs : now,
      count: count + 1,
      expiresAt: Timestamp.fromMillis(now + RATE_LIMIT_WINDOW_MS * 2),
    });
  });
}

async function fetchWithValidatedRedirects(targetUrl) {
  let currentUrl = targetUrl;

  for (let redirectCount = 0; redirectCount <= MAX_REDIRECTS; redirectCount++) {
    await assertPublicDns(currentUrl.hostname);

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);

    let response;
    try {
      response = await fetch(currentUrl, {
        redirect: "manual",
        signal: controller.signal,
        headers: {
          "Accept": "image/jpeg, image/png",
          "User-Agent": "PAWLINK-Image-Proxy/2.0",
        },
      });
    } catch (error) {
      clearTimeout(timeout);
      if (error.name === "AbortError") {
        throw new HttpError(504, "Upstream image request timed out");
      }
      throw error;
    }

    if (response.status >= 300 && response.status < 400) {
      clearTimeout(timeout);
      if (response.body) await response.body.cancel();
      const location = response.headers.get("location");
      if (!location || redirectCount === MAX_REDIRECTS) {
        throw new HttpError(502, "Invalid or excessive upstream redirect");
      }
      currentUrl = parseAllowedTarget(location, currentUrl);
      continue;
    }

    return {response, controller, timeout};
  }

  throw new HttpError(502, "Excessive upstream redirects");
}

async function readLimitedBody(response, controller, timeout) {
  const declaredLength = Number(response.headers.get("content-length"));
  if (Number.isFinite(declaredLength) && declaredLength > MAX_RESPONSE_BYTES) {
    controller.abort();
    clearTimeout(timeout);
    throw new HttpError(413, "Upstream image is too large");
  }

  const chunks = [];
  let totalBytes = 0;
  try {
    for await (const chunk of response.body) {
      const buffer = Buffer.from(chunk);
      totalBytes += buffer.length;
      if (totalBytes > MAX_RESPONSE_BYTES) {
        controller.abort();
        throw new HttpError(413, "Upstream image is too large");
      }
      chunks.push(buffer);
    }
  } catch (error) {
    if (error.name === "AbortError") {
      throw new HttpError(504, "Upstream image request timed out");
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
  return Buffer.concat(chunks, totalBytes);
}

exports.corsProxy = onRequest({
  maxInstances: 10,
  timeoutSeconds: 15,
}, async (req, res) => {
  res.setHeader("Content-Security-Policy", "default-src 'none'; sandbox");
  res.setHeader("Cross-Origin-Resource-Policy", "same-origin");
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("X-Frame-Options", "DENY");

  try {
    if (req.method !== "GET") {
      res.setHeader("Allow", "GET");
      throw new HttpError(405, "Method not allowed");
    }

    const token = await authenticate(req);

    if (typeof req.query.url !== "string" || req.query.url.length > 2048) {
      throw new HttpError(400, "A valid target URL is required");
    }
    const targetUrl = parseAllowedTarget(req.query.url);
    await consumeQuota(token.uid);

    const {response, controller, timeout} =
      await fetchWithValidatedRedirects(targetUrl);

    if (!response.ok) {
      controller.abort();
      clearTimeout(timeout);
      throw new HttpError(502, "Upstream image request failed");
    }

    const contentType = (response.headers.get("content-type") || "")
      .split(";", 1)[0]
      .trim()
      .toLowerCase();
    if (!ALLOWED_IMAGE_TYPES.has(contentType)) {
      controller.abort();
      clearTimeout(timeout);
      throw new HttpError(415, "Upstream response is not an allowed image type");
    }

    const body = await readLimitedBody(response, controller, timeout);
    if (!hasAllowedImageSignature(contentType, body)) {
      throw new HttpError(415, "Upstream content is not a valid allowed image");
    }

    res.setHeader("Content-Type", contentType);
    res.setHeader("Content-Length", body.length);
    res.setHeader("Cache-Control", "private, max-age=3600");
    res.status(200).send(body);
  } catch (error) {
    const status = error instanceof HttpError ?
      error.status :
      error instanceof TargetValidationError ? 400 : 500;
    if (status >= 500) {
      logger.error("Image proxy error", {error: error.message});
    }
    res.type("text/plain").status(status).send(
      status === 500 ? "Image proxy request failed" : error.message,
    );
  }
});

exports.reserveCommunicationCredit = creditOperations.reserveCommunicationCredit;
exports.settleCommunicationCredit = creditOperations.settleCommunicationCredit;
exports.releaseCommunicationCredit = creditOperations.releaseCommunicationCredit;
exports.releaseExpiredCommunicationCredits =
  creditOperations.releaseExpiredCommunicationCredits;
exports.deleteOwnAccount = accountOperations.deleteOwnAccount;
exports.deletePetData = accountOperations.deletePetData;
exports.retrieveKnowledge = knowledgeRetrieval.retrieveKnowledge;
