import 'package:ai_pet_communication/core/domain/app_request.dart';
import 'package:ai_pet_communication/core/data/firebase_failure.dart';
import 'package:ai_pet_communication/core/errors/service_failure.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ai_pet_communication/core/domain/request_repository.dart';
import 'request_wire_mapper.dart';
import 'dart:convert';

class FirebaseRequestRepository implements RequestRepository {
  @override
  final String uid;
  final FirebaseAuth auth;
  final FirebaseFunctions functions;
  FirebaseRequestRepository({
    required this.uid,
    required this.auth,
    required this.functions,
  });
  @override
  bool get isCurrentSession => auth.currentUser?.uid == uid;
  @override
  Stream<bool> get sessionChanges =>
      auth.authStateChanges().map((u) => u?.uid == uid);
  @override
  String requestKey(AppRequest<void> request) {
    final (name, values) = encodeAppRequest(request);
    return jsonEncode([name, values]);
  }

  @override
  Future<T> execute<T>(AppRequest<T> request, {String? operationId}) async {
    final (name, values) = encodeAppRequest(request);
    final result = await _call(name, {...values, 'operationId': ?operationId});
    return decodeAppResponse(request, result);
  }

  Future<Map<String, dynamic>> _call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) => mapFirebaseFailure(() async {
    if (!isCurrentSession) {
      throw const ServiceFailure(
        FailureKind.sessionChanged,
        message: '帳號已變更，請返回首頁',
      );
    }
    final result = await functions
        .httpsCallable(
          name,
          options: HttpsCallableOptions(timeout: const Duration(seconds: 65)),
        )
        .call<Map<String, dynamic>>(data);
    if (!isCurrentSession) {
      throw const ServiceFailure(
        FailureKind.sessionChanged,
        message: '帳號已變更，請返回首頁',
      );
    }
    return Map<String, dynamic>.from(result.data);
  });
}
