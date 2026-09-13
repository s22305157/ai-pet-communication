import 'package:firebase_core/firebase_core.dart';
import '../errors/service_failure.dart';

ServiceFailure firebaseFailure(FirebaseException error) =>
    ServiceFailure(switch (error.code) {
      'unauthenticated' => FailureKind.unauthenticated,
      'cancelled' => FailureKind.sessionChanged,
      'permission-denied' => FailureKind.permissionDenied,
      'aborted' => FailureKind.conflict,
      'unavailable' => FailureKind.unavailable,
      'deadline-exceeded' => FailureKind.timeout,
      'internal' => FailureKind.internal,
      'resource-exhausted' => FailureKind.quotaExceeded,
      'not-found' => FailureKind.notFound,
      'invalid-argument' => FailureKind.invalidInput,
      'already-exists' => FailureKind.alreadyExists,
      _ => FailureKind.unknown,
    }, message: error.message);

Future<T> mapFirebaseFailure<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on FirebaseException catch (error) {
    throw firebaseFailure(error);
  }
}
