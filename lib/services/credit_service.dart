import 'package:cloud_functions/cloud_functions.dart';

class CreditReservation {
  final String requestId;
  final String status;
  final int? pointsRemaining;

  const CreditReservation({
    required this.requestId,
    required this.status,
    this.pointsRemaining,
  });
}

class CreditService {
  final FirebaseFunctions _functions;

  CreditService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  Future<CreditReservation> reserveCommunication({
    required String requestId,
    required String petId,
  }) async {
    final result = await _functions
        .httpsCallable('reserveCommunicationCredit')
        .call(<String, dynamic>{'requestId': requestId, 'petId': petId});
    final data = Map<String, dynamic>.from(result.data as Map);
    if (data['status'] != 'reserved') {
      throw StateError('Credit request is not reserved.');
    }
    return CreditReservation(
      requestId: data['requestId'] as String,
      status: data['status'] as String,
      pointsRemaining: data['pointsRemaining'] as int?,
    );
  }

  Future<void> settleCommunication(String requestId) async {
    final result = await _functions
        .httpsCallable('settleCommunicationCredit')
        .call(<String, dynamic>{'requestId': requestId});
    final data = Map<String, dynamic>.from(result.data as Map);
    if (data['status'] != 'settled') {
      throw StateError('Credit reservation could not be settled.');
    }
  }

  Future<void> releaseCommunication(String requestId) async {
    await _functions.httpsCallable('releaseCommunicationCredit').call(
      <String, dynamic>{'requestId': requestId},
    );
  }
}
