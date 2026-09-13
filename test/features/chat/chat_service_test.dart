import 'package:ai_pet_communication/core/errors/service_failure.dart';
import 'package:ai_pet_communication/features/chat/data/chat_service.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_safe_response_model.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_validation_exception.dart';
import 'chat_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'maps a typed consultation to the envelope and parses a typed result',
    () async {
      final service = ChatService(
        currentUserId: () => 'user1',
        call: (data) async {
          expect(data, {
            'requestId': sampleConsultation.requestId,
            'petId': sampleConsultation.petId,
            'request': sampleConsultation.request.toMap(),
          });
          return {'response': sampleSafeResponse};
        },
      );
      final response = await service.sendMessage(sampleConsultation);
      expect(response, isA<AiSafeResponseModel>());
      expect((response as AiSafeResponseModel).petVoice.text, '先觀察作息');
    },
  );
  test('rejects missing and malformed backend responses', () async {
    for (final value in [
      {},
      {'response': ''},
    ]) {
      final service = ChatService(
        currentUserId: () => 'user1',
        call: (_) async => value,
      );
      await expectLater(
        service.sendMessage(sampleConsultation),
        throwsFormatException,
      );
    }
    final service = ChatService(
      currentUserId: () => 'user1',
      call: (_) async => {'response': '{"summary":"incomplete"}'},
    );
    await expectLater(
      service.sendMessage(sampleConsultation),
      throwsA(isA<AiValidationException>()),
    );
  });
  test(
    'does not send a consultation without an authenticated account',
    () async {
      final service = ChatService(
        currentUserId: () => null,
        call: (_) async => fail('Must not call backend'),
      );
      await expectLater(
        service.sendMessage(sampleConsultation),
        throwsA(
          isA<ServiceFailure>().having(
            (e) => e.kind,
            'kind',
            FailureKind.unauthenticated,
          ),
        ),
      );
    },
  );
  test('drops an in-flight response after account switching', () async {
    var uid = 'user1';
    final service = ChatService(
      currentUserId: () => uid,
      call: (_) async {
        uid = 'user2';
        return {'response': sampleSafeResponse};
      },
    );
    await expectLater(
      service.sendMessage(sampleConsultation),
      throwsA(
        isA<ServiceFailure>().having(
          (e) => e.kind,
          'kind',
          FailureKind.sessionChanged,
        ),
      ),
    );
  });
}
