const dns = require("node:dns").promises;
const net = require("node:net");

const ALLOWED_HOSTS = new Set(["lh3.googleusercontent.com"]);

class TargetValidationError extends Error {}

function parseAllowedTarget(rawUrl, baseUrl) {
  let url;
  try {
    url = baseUrl ? new URL(rawUrl, baseUrl) : new URL(rawUrl);
  } catch (_) {
    throw new TargetValidationError("Invalid target URL");
  }

  if (url.protocol !== "https:") {
    throw new TargetValidationError("Only HTTPS image URLs are allowed");
  }
  if (url.username || url.password || (url.port && url.port !== "443")) {
    throw new TargetValidationError(
      "URL credentials and non-standard ports are not allowed",
    );
  }
  if (!ALLOWED_HOSTS.has(url.hostname.toLowerCase())) {
    throw new TargetValidationError("Image host is not allowed");
  }

  return url;
}

function isPrivateOrReservedIpv4(address) {
  const octets = address.split(".").map(Number);
  if (octets.length !== 4 || octets.some((value) =>
    !Number.isInteger(value) || value < 0 || value > 255)) {
    return true;
  }

  const [a, b, c] = octets;
  return a === 0 ||
    a === 10 ||
    a === 127 ||
    (a === 100 && b >= 64 && b <= 127) ||
    (a === 169 && b === 254) ||
    (a === 172 && b >= 16 && b <= 31) ||
    (a === 192 && b === 0 && c === 0) ||
    (a === 192 && b === 0 && c === 2) ||
    (a === 192 && b === 168) ||
    (a === 198 && (b === 18 || b === 19)) ||
    (a === 198 && b === 51 && c === 100) ||
    (a === 203 && b === 0 && c === 113) ||
    a >= 224;
}

function isPrivateOrReservedIp(address) {
  const family = net.isIP(address);
  if (family === 4) return isPrivateOrReservedIpv4(address);
  if (family !== 6) return true;

  const normalized = address.toLowerCase();
  const mappedIpv4 = normalized.match(/::ffff:(\d+\.\d+\.\d+\.\d+)$/);
  if (mappedIpv4) return isPrivateOrReservedIpv4(mappedIpv4[1]);

  return normalized === "::" ||
    normalized === "::1" ||
    normalized.startsWith("fc") ||
    normalized.startsWith("fd") ||
    /^fe[89ab]/.test(normalized) ||
    normalized.startsWith("ff") ||
    normalized.startsWith("2001:db8:");
}

async function assertPublicDns(hostname) {
  const addresses = await dns.lookup(hostname, {all: true, verbatim: true});
  if (addresses.length === 0 ||
      addresses.some(({address}) => isPrivateOrReservedIp(address))) {
    throw new Error("Image host resolved to a non-public address");
  }
}

function hasAllowedImageSignature(contentType, body) {
  if (contentType === "image/jpeg") {
    return body.length >= 3 &&
      body[0] === 0xff &&
      body[1] === 0xd8 &&
      body[2] === 0xff;
  }

  if (contentType === "image/png") {
    const pngSignature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
    return body.length >= pngSignature.length &&
      pngSignature.every((byte, index) => body[index] === byte);
  }

  return false;
}

module.exports = {
  TargetValidationError,
  parseAllowedTarget,
  isPrivateOrReservedIp,
  assertPublicDns,
  hasAllowedImageSignature,
};
