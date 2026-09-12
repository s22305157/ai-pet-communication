import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/pilot_repository.dart';
import '../domain/pilot_request.dart';
import 'pilot_wire_mapper.dart';
import 'dart:convert';

class FirebasePilotRepository implements PilotRepository {
  @override
  final String uid;
  final FirebaseAuth auth;
  final FirebaseFunctions functions;
  FirebasePilotRepository({
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
  String requestKey(PilotRequest<void> request) {
    final (name, values) = encodePilotRequest(request);
    return jsonEncode([name, values]);
  }

  @override
  Future<T> execute<T>(PilotRequest<T> request, {String? operationId}) async {
    final (name, values) = encodePilotRequest(request);
    final result = await call(name, {...values, 'operationId': ?operationId});
    return decodePilotResponse(request, result);
  }

  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (!isCurrentSession) throw StateError('帳號已變更，請返回首頁');
    final result = await functions
        .httpsCallable(
          name,
          options: HttpsCallableOptions(timeout: const Duration(seconds: 65)),
        )
        .call<Map<String, dynamic>>(data);
    if (!isCurrentSession) throw StateError('帳號已變更，請返回首頁');
    return Map<String, dynamic>.from(result.data);
  }
}
