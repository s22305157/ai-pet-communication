enum FailureKind {
  unauthenticated,
  sessionChanged,
  permissionDenied,
  conflict,
  unavailable,
  timeout,
  internal,
  quotaExceeded,
  notFound,
  invalidInput,
  alreadyExists,
  unknown,
}

/// Stable application failures; external SDK exceptions stop at the data layer.
class ServiceFailure implements Exception {
  final FailureKind kind;
  final String? message;
  const ServiceFailure(this.kind, {this.message});

  bool get isRetryable => const {
    FailureKind.unavailable,
    FailureKind.timeout,
    FailureKind.internal,
    FailureKind.unknown,
  }.contains(kind);

  bool get isSessionFailure => const {
    FailureKind.unauthenticated,
    FailureKind.sessionChanged,
    FailureKind.permissionDenied,
  }.contains(kind);

  @override
  String toString() => message ?? '服務暫時無法完成，請稍後重試';
}
