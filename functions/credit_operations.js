const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {
  CreditOperationError,
  validateRequestId,
  planTransition,
} = require("./credit_logic");


function requireUid(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication required");
  }
  return request.auth.uid;
}

function asHttpsError(error) {
  if (error instanceof HttpsError) return error;
  if (error instanceof CreditOperationError) {
    return new HttpsError(error.code, error.message);
  }
  return new HttpsError("internal", "Credit operation failed");
}

async function reserveCommunicationCreditHandler(request) {
  requireUid(request);
  throw new HttpsError('failed-precondition', '溝通點數收費尚未設定');
}

async function transitionCredit(request, targetStatus) {
  try {
    const uid = requireUid(request);
    if (targetStatus === 'settled') throw new HttpsError('failed-precondition', '溝通點數收費尚未設定');
    const requestId = validateRequestId(request.data && request.data.requestId);
    const db = getFirestore();
    const userRef = db.collection("users").doc(uid);
    const operationRef = userRef.collection("creditOperations").doc(requestId);

    return await db.runTransaction(async (transaction) => {
      const operationSnapshot = await transaction.get(operationRef);
      const operation = operationSnapshot.exists ? operationSnapshot.data() : null;
      if (operation?.aiStatus === 'processing' &&
          Date.now() - operation.aiStartedAtMs < 120000) {
        throw new CreditOperationError('failed-precondition', 'AI communication is still processing');
      }
      const plan = planTransition(operation, targetStatus);
      if (!plan.change) return {requestId, status: plan.status};

      if (plan.refund) {
        const userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) {
          throw new CreditOperationError("not-found", "User account not found");
        }
        const points = userSnapshot.get("points");
        if (!Number.isInteger(points) || points < 0) {
          throw new CreditOperationError("failed-precondition", "Invalid point balance");
        }
        transaction.update(userRef, {points: points + operation.amount});
      }
      transaction.update(operationRef, {
        status: targetStatus,
        updatedAt: FieldValue.serverTimestamp(),
        expiresAt: FieldValue.delete(),
      });
      return {requestId, status: targetStatus};
    });
  } catch (error) {
    throw asHttpsError(error);
  }
}

exports.reserveCommunicationCredit = onCall(
  {maxInstances: 20},
  reserveCommunicationCreditHandler,
);
exports.settleCommunicationCredit = onCall(
  {maxInstances: 20},
  (request) => transitionCredit(request, "settled"),
);
exports.releaseCommunicationCredit = onCall(
  {maxInstances: 20},
  (request) => transitionCredit(request, "released"),
);

// App 被強制關閉或離線時，最晚在預留逾期後由後端補償退點。
exports.releaseExpiredCommunicationCredits = onSchedule(
  {schedule: "every 15 minutes", timeZone: "Etc/UTC"},
  async () => {
    const db = getFirestore();
    const expired = await db.collectionGroup("creditOperations")
      .where("expiresAt", "<=", Timestamp.now())
      .limit(100)
      .get();

    await Promise.all(expired.docs.map(async (snapshot) => {
      const operationRef = snapshot.ref;
      const userRef = operationRef.parent.parent;
      if (!userRef) return;
      await db.runTransaction(async (transaction) => {
        const [operationSnapshot, userSnapshot] = await Promise.all([
          transaction.get(operationRef),
          transaction.get(userRef),
        ]);
        const operation = operationSnapshot.exists ? operationSnapshot.data() : null;
        const plan = planTransition(operation, "released");
        if (!plan.change) return;
        if (!userSnapshot.exists) return;
        const points = userSnapshot.get("points");
        if (!Number.isInteger(points) || points < 0) return;
        transaction.update(userRef, {points: points + operation.amount});
        transaction.update(operationRef, {
          status: "released",
          releaseReason: "expired",
          updatedAt: FieldValue.serverTimestamp(),
          expiresAt: FieldValue.delete(),
        });
      });
    }));
  },
);

exports._handlers = {
  reserveCommunicationCreditHandler,
  transitionCredit,
};
