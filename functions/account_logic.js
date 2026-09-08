function ownedAvatarPath(avatarUrl, uid, bucketName) {
  if (typeof avatarUrl !== "string" || avatarUrl.length > 4096) return null;
  try {
    const url = new URL(avatarUrl);
    let objectPath;
    if (url.hostname === "firebasestorage.googleapis.com") {
      const match = url.pathname.match(/^\/v0\/b\/([^/]+)\/o\/(.+)$/);
      if (!match || decodeURIComponent(match[1]) !== bucketName) return null;
      objectPath = decodeURIComponent(match[2]);
    } else if (url.hostname === "storage.googleapis.com") {
      const prefix = `/${bucketName}/`;
      if (!url.pathname.startsWith(prefix)) return null;
      objectPath = decodeURIComponent(url.pathname.substring(prefix.length));
    } else {
      return null;
    }
    return objectPath.startsWith(`pets/${uid}/`) ? objectPath : null;
  } catch (_) {
    return null;
  }
}

function hasRecentAuthentication(authTime, nowSeconds, maxAgeSeconds = 300) {
  return Number.isInteger(authTime) &&
    Number.isFinite(nowSeconds) &&
    authTime <= nowSeconds &&
    nowSeconds - authTime <= maxAgeSeconds;
}

module.exports = {ownedAvatarPath, hasRecentAuthentication};
