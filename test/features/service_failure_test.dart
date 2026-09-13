import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:ai_pet_communication/core/data/firebase_failure.dart';
import 'package:ai_pet_communication/core/errors/service_failure.dart';
import 'package:ai_pet_communication/features/journal/application/journal_controller.dart';

void main() {
  test(
    'pending and permanent preconditions have distinct operation lifetimes',
    () {
      for (final reason in ['request-pending', 'request-failed', null]) {
        final failure = firebaseFailure(
          FirebaseFunctionsException(
            code: 'failed-precondition',
            message: 'precondition',
            details: {'reason': reason},
          ),
        );
        expect(
          failure.kind,
          reason == 'request-pending'
              ? FailureKind.pending
              : FailureKind.failedPrecondition,
        );
        expect(failure.isRetryable, isFalse);
        expect(failure.preservesOperationId, reason == 'request-pending');
      }
      const unknown = ServiceFailure(FailureKind.unknown);
      expect(unknown.isRetryable, isFalse);
      expect(unknown.preservesOperationId, isTrue);
    },
  );
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
