class OperationError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function validatePetId(value) {
  if (typeof value !== "string" || value.length < 1 || value.length > 128 ||
      value.includes("/")) {
    throw new OperationError("invalid-argument", "Invalid pet ID");
  }
  return value;
}

module.exports = {OperationError, validatePetId};
