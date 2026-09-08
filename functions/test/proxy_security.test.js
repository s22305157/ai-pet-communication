const test = require("node:test");
const assert = require("node:assert/strict");
const {
  parseAllowedTarget,
  isPrivateOrReservedIp,
  hasAllowedImageSignature,
} = require("../proxy_security");

test("allows only the trusted Google profile image host", () => {
  assert.equal(
    parseAllowedTarget("https://lh3.googleusercontent.com/a/photo").hostname,
    "lh3.googleusercontent.com",
  );
  assert.throws(() => parseAllowedTarget("https://example.com/photo.jpg"));
  assert.throws(() => parseAllowedTarget("https://127.0.0.1/private"));
  assert.throws(() => parseAllowedTarget("http://lh3.googleusercontent.com/a/photo"));
});

test("revalidates redirect destinations against the same allowlist", () => {
  const source = new URL("https://lh3.googleusercontent.com/a/photo");
  assert.throws(() => parseAllowedTarget("http://127.0.0.1/private", source));
  assert.throws(() => parseAllowedTarget("https://example.com/photo", source));
});

test("blocks private and reserved IP ranges", () => {
  for (const address of [
    "127.0.0.1",
    "10.0.0.1",
    "172.16.0.1",
    "192.168.1.1",
    "169.254.169.254",
    "100.64.0.1",
    "::1",
    "fd00::1",
    "fe80::1",
    "::ffff:127.0.0.1",
  ]) {
    assert.equal(isPrivateOrReservedIp(address), true, address);
  }
  assert.equal(isPrivateOrReservedIp("8.8.8.8"), false);
  assert.equal(isPrivateOrReservedIp("2001:4860:4860::8888"), false);
});

test("accepts JPEG and PNG signatures only when MIME matches", () => {
  const jpeg = Buffer.from([0xff, 0xd8, 0xff, 0xe0]);
  const png = Buffer.from([
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
  ]);

  assert.equal(hasAllowedImageSignature("image/jpeg", jpeg), true);
  assert.equal(hasAllowedImageSignature("image/png", png), true);
  assert.equal(hasAllowedImageSignature("image/png", jpeg), false);
  assert.equal(hasAllowedImageSignature("image/jpeg", png), false);
});

test("rejects HTML, SVG, and WebP even with a spoofed image MIME", () => {
  const html = Buffer.from("<script>alert(1)</script>");
  const svg = Buffer.from("<svg onload='alert(1)'></svg>");
  const webp = Buffer.from("RIFF0000WEBP");

  for (const body of [html, svg, webp]) {
    assert.equal(hasAllowedImageSignature("image/jpeg", body), false);
    assert.equal(hasAllowedImageSignature("image/png", body), false);
  }
  assert.equal(hasAllowedImageSignature("text/html", html), false);
  assert.equal(hasAllowedImageSignature("image/svg+xml", svg), false);
});
