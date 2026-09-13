import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:ai_pet_communication/core/data/firebase_failure.dart';
import 'package:ai_pet_communication/core/errors/service_failure.dart';
import 'package:ai_pet_communication/features/journal/application/journal_controller.dart';

void main() {
  test(
    'transport errors preserve retry and conflict meaning without string matching',
    () async {
      await expectLater(
        mapFirebaseFailure(() async {
          throw FirebaseFunctionsException(
            code: 'aborted',
            message: 'new revision',
          );
        }),
        throwsA(
          isA<ServiceFailure>().having(
            (e) => e.kind,
            'kind',
            FailureKind.conflict,
          ),
        ),
      );
      final timeout = firebaseFailure(
        FirebaseFunctionsException(
          code: 'deadline-exceeded',
          message: 'timeout',
        ),
      );
      expect(timeout.isRetryable, isTrue);
      expect(
        firebaseFailure(
          FirebaseFunctionsException(
            code: 'permission-denied',
            message: 'denied',
          ),
        ).isSessionFailure,
        isTrue,
      );
      expect(
        journalError(Exception('a text mentioning aborted')),
        isNot(contains('雲端已有新版本')),
      );
      expect(
        journalError(const ServiceFailure(FailureKind.conflict)),
        contains('雲端已有新版本'),
      );
    },
  );
}
