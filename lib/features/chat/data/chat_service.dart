import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ai_pet_communication/core/data/firebase_failure.dart';
import 'package:ai_pet_communication/core/errors/service_failure.dart';
import '../domain/chat_repository.dart';

typedef AiCallable = Future<dynamic> Function(Map<String, dynamic> request);

class ChatService implements ChatRepository {
  final FirebaseFunctions? _functions;
  final AiCallable? _call;
  final String? Function() _currentUserId;

  ChatService({
    FirebaseFunctions? functions,
    AiCallable? call,
    String? Function()? currentUserId,
  }) : _functions = functions,
       _call = call,
       _currentUserId =
           currentUserId ?? (() => FirebaseAuth.instance.currentUser?.uid);

  @override
  Future<String> sendMessage(String message) => mapFirebaseFailure(() async {
    final request = jsonDecode(message);
    if (request is! Map<String, dynamic> ||
        request['request'] is! Map ||
        request['petId'] is! String ||
        request['requestId'] is! String) {
      throw const FormatException('A structured consultation is required');
    }
    final dynamic result;
    final ownerId = _currentUserId();
    if (ownerId == null) {
      throw const ServiceFailure(FailureKind.unauthenticated, message: '請先登入');
    }
    try {
      if (_call != null) {
        result = await _call(request);
      } else {
        result =
            (await (_functions ?? FirebaseFunctions.instance)
                    .httpsCallable(
                      'communicateWithPet',
                      options: HttpsCallableOptions(
                        timeout: const Duration(seconds: 100),
                      ),
                    )
                    .call<dynamic>(request))
                .data;
      }
    } catch (_) {
      if (_currentUserId() != ownerId) {
        throw const ServiceFailure(
          FailureKind.sessionChanged,
          message: '登入帳號已變更',
        );
      }
      rethrow;
    }
    if (_currentUserId() != ownerId) {
      throw const ServiceFailure(
        FailureKind.sessionChanged,
        message: '登入帳號已變更',
      );
    }
    if (result is! Map ||
        result['response'] is! String ||
        (result['response'] as String).trim().isEmpty) {
      throw const FormatException('AI response is missing');
    }
    return result['response'] as String;
  });
}
