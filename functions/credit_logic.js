const CREDIT_AMOUNT = 1;

class CreditOperationError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function validateRequestId(value) {
  if (typeof value !== "string" ||
      !/^[A-Za-z0-9_-]{16,128}$/.test(value)) {
    throw new CreditOperationError("invalid-argument", "Invalid request ID");
  }
  return value;
}

function validatePetId(value) {
  if (typeof value !== "string" || value.length < 1 || value.length > 128 ||
      value.includes("/")) {
    throw new CreditOperationError("invalid-argument", "Invalid pet ID");
  }
  return value;
}

function planReservation({existingOperation, points, petId}) {
  if (existingOperation) {
    if (existingOperation.kind !== "communication" ||
        existingOperation.amount !== CREDIT_AMOUNT ||
        existingOperation.petId !== petId) {
      throw new CreditOperationError(
        "failed-precondition",
        "Request ID was already used for another operation",
      );
    }
    return {
      create: false,
      status: existingOperation.status,
      pointsRemaining: existingOperation.pointsAfterReservation,
    };
  }

  if (!Number.isInteger(points) || points < CREDIT_AMOUNT) {
    throw new CreditOperationError("failed-precondition", "Insufficient points");
  }

  return {
    create: true,
    status: "reserved",
    pointsRemaining: points - CREDIT_AMOUNT,
  };
}

function planTransition(operation, targetStatus) {
  if (!operation || operation.kind !== "communication" ||
      operation.amount !== CREDIT_AMOUNT) {
    throw new CreditOperationError("not-found", "Credit reservation not found");
  }
  if (targetStatus !== "settled" && targetStatus !== "released") {
    throw new CreditOperationError("invalid-argument", "Invalid transition");
  }
  if (operation.status === targetStatus) {
    return {change: false, status: targetStatus, refund: false};
  }
  if (operation.status === "settled" || operation.status === "released") {
    return {change: false, status: operation.status, refund: false};
  }
  if (operation.status !== "reserved") {
    throw new CreditOperationError("failed-precondition", "Invalid reservation state");
  }
  return {
    change: true,
    status: targetStatus,
    refund: targetStatus === "released",
  };
}

module.exports = {
  CREDIT_AMOUNT,
  CreditOperationError,
  validateRequestId,
  validatePetId,
  planReservation,
  planTransition,
};
