import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef AiCallable = Future<dynamic> Function(Map<String, dynamic> request);

class ChatService {
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

  Future<String> sendMessage(String message) async {
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
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: '請先登入',
      );
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
        throw FirebaseFunctionsException(code: 'cancelled', message: '登入帳號已變更');
      }
      rethrow;
    }
    if (_currentUserId() != ownerId) {
      throw FirebaseFunctionsException(code: 'cancelled', message: '登入帳號已變更');
    }
    if (result is! Map ||
        result['response'] is! String ||
        (result['response'] as String).trim().isEmpty) {
      throw const FormatException('AI response is missing');
    }
    return result['response'] as String;
  }
}
