const test = require("node:test");
const assert = require("node:assert/strict");
const {
  ownedAvatarPath,
  hasRecentAuthentication,
} = require("../account_logic");

test("accepts only an avatar object in the authenticated user's bucket path", () => {
  const bucket = "pawlink.appspot.com";
  assert.equal(
    ownedAvatarPath(
      "https://firebasestorage.googleapis.com/v0/b/pawlink.appspot.com/o/" +
        "pets%2Fuser-1%2Favatar.png?alt=media&token=x",
      "user-1",
      bucket,
    ),
    "pets/user-1/avatar.png",
  );
  assert.equal(
    ownedAvatarPath(
      "https://firebasestorage.googleapis.com/v0/b/pawlink.appspot.com/o/" +
        "pets%2Fuser-2%2Favatar.png",
      "user-1",
      bucket,
    ),
    null,
  );
  assert.equal(
    ownedAvatarPath("https://attacker.example/pets/user-1/avatar.png", "user-1", bucket),
    null,
  );
});

test("requires authentication no older than five minutes", () => {
  assert.equal(hasRecentAuthentication(700, 1000), true);
  assert.equal(hasRecentAuthentication(699, 1000), false);
  assert.equal(hasRecentAuthentication(1001, 1000), false);
  assert.equal(hasRecentAuthentication(undefined, 1000), false);
});
