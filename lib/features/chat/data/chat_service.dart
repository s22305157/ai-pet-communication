import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ai_pet_communication/core/data/firebase_failure.dart';
import 'package:ai_pet_communication/core/errors/service_failure.dart';
import '../domain/chat_repository.dart';
import '../domain/chat_consultation.dart';
import '../domain/communication_response.dart';
import 'chat_response_mapper.dart';

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
  Future<CommunicationResponse> sendMessage(ChatConsultation consultation) =>
      mapFirebaseFailure(() async {
        final request = ChatResponseMapper.request(consultation);
        final dynamic result;
        final ownerId = _currentUserId();
        if (ownerId == null) {
          throw const ServiceFailure(
            FailureKind.unauthenticated,
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
        return ChatResponseMapper.fromCallable(
          result,
          useSafeMode: consultation.useSafeMode,
        );
      });
}
