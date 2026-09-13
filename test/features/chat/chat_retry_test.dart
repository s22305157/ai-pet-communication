import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ai_pet_communication/core/errors/service_failure.dart';
import 'package:ai_pet_communication/features/chat/application/chat_controller.dart';
import 'package:ai_pet_communication/features/chat/data/chat_service.dart';
import 'package:ai_pet_communication/features/readings/application/reading_service.dart';
import 'package:ai_pet_communication/features/readings/domain/reading.dart';
import 'chat_fixtures.dart';

class _Readings extends Mock implements ReadingService {}

void main() {
  late _Readings readings;
  setUp(() {
    readings = _Readings();
    when(
      () => readings.recordAiResponse(
        petId: any(named: 'petId'),
        aiText: any(named: 'aiText'),
        source: any(named: 'source'),
      ),
    ).thenAnswer((_) async {});
  });
  for (final kind in FailureKind.values) {
    test(
      '$kind follows the retry policy and preserves the original request ID',
      () async {
        final calls = <Map<String, dynamic>>[];
        final service = ChatService(
          currentUserId: () => 'a',
          call: (data) async {
            calls.add(data);
            throw ServiceFailure(kind);
          },
        );
        final controller = ChatController(service, readings);
        final outcome = await controller.handleCommunicationWithPersistence(
          'pet1',
          sampleConsultation.request,
          requestId: 'same-request-id',
        );
        final retryable = [
          FailureKind.unavailable,
          FailureKind.timeout,
          FailureKind.internal,
        ].contains(kind);
        expect(calls.length, retryable ? 2 : 1);
        expect(
          calls.every((data) => data['requestId'] == 'same-request-id'),
          isTrue,
        );
        expect(outcome.isFallback, isTrue);
        verifyNever(
          () => readings.recordAiResponse(
            petId: any(named: 'petId'),
            aiText: any(named: 'aiText'),
            source: any(named: 'source'),
          ),
        );
      },
    );
  }
  test(
    'unknown exceptions and malformed responses never re-send a request',
    () async {
      for (final failure in [
        StateError('unknown'),
        const FormatException('bad response'),
      ]) {
        var calls = 0;
        final service = ChatService(
          currentUserId: () => 'a',
          call: (_) async {
            calls++;
            if (failure is StateError) throw failure;
            return {'response': 'not valid JSON'};
          },
        );
        final result = await ChatController(service, readings)
            .handleCommunicationWithPersistence(
              'pet1',
              sampleConsultation.request,
            );
        expect(result.isFallback, isTrue);
        expect(calls, 1);
      }
    },
  );
  test(
    'retrying persistence saves the same reading without calling AI again',
    () async {
      var calls = 0;
      final service = ChatService(
        currentUserId: () => 'a',
        call: (_) async {
          calls++;
          return {'response': sampleSafeResponse};
        },
      );
      final reading = Reading(
        id: 'retained-id',
        petId: 'pet1',
        title: 'title',
        content: sampleSafeResponse,
        createdAt: DateTime(2026),
      );
      when(
        () => readings.recordAiResponse(
          petId: any(named: 'petId'),
          aiText: any(named: 'aiText'),
          source: any(named: 'source'),
        ),
      ).thenThrow(
        ReadingPersistenceException(
          reading,
          StateError('offline'),
          StackTrace.current,
        ),
      );
      when(() => readings.saveReading(reading)).thenAnswer((_) async {});
      final controller = ChatController(service, readings);
      final outcome = await controller.handleCommunicationWithPersistence(
        'pet1',
        sampleConsultation.request,
      );
      expect(outcome.isFallback, isFalse);
      await controller.retryPersistence(outcome);
      verify(() => readings.saveReading(reading)).called(1);
      expect(calls, 1);
    },
  );
}
