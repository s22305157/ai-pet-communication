const test = require("node:test");
const assert = require("node:assert/strict");
const {
  CreditOperationError,
  planReservation,
  planTransition,
} = require("../credit_logic");

test("reservation refuses an insufficient balance instead of going negative", () => {
  assert.throws(
    () => planReservation({existingOperation: null, points: 0, petId: "pet-1"}),
    (error) => error instanceof CreditOperationError &&
      error.code === "failed-precondition",
  );
});

test("a repeated request ID is idempotent", () => {
  const operation = {
    kind: "communication",
    amount: 1,
    petId: "pet-1",
    status: "reserved",
    pointsAfterReservation: 0,
  };
  assert.deepEqual(
    planReservation({existingOperation: operation, points: 0, petId: "pet-1"}),
    {create: false, status: "reserved", pointsRemaining: 0},
  );
});

test("release refunds exactly once and settlement never refunds", () => {
  const reserved = {kind: "communication", amount: 1, status: "reserved"};
  assert.deepEqual(planTransition(reserved, "released"), {
    change: true,
    status: "released",
    refund: true,
  });
  assert.deepEqual(
    planTransition({...reserved, status: "released"}, "released"),
    {change: false, status: "released", refund: false},
  );
  assert.deepEqual(planTransition(reserved, "settled"), {
    change: true,
    status: "settled",
    refund: false,
  });
});
