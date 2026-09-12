class PilotInterest {
  final bool interested, metricsConsent, canExpressInterest, cleanupPending;
  const PilotInterest({
    required this.interested,
    required this.metricsConsent,
    required this.canExpressInterest,
    required this.cleanupPending,
  });
}

class PilotRatio {
  final int numerator, denominator, pending;
  const PilotRatio({
    required this.numerator,
    required this.denominator,
    required this.pending,
  });
  double? get rate => denominator == 0 ? null : numerator / denominator;
}

class PilotMetrics {
  final int fromMs,
      toMs,
      measuredParticipants,
      incompleteCohorts,
      legacyUnlinkedEvents;
  final PilotRatio activation,
      retention,
      reviewViews,
      communityResponses,
      upgradeInterest;
  const PilotMetrics({
    required this.fromMs,
    required this.toMs,
    required this.measuredParticipants,
    required this.incompleteCohorts,
    required this.legacyUnlinkedEvents,
    required this.activation,
    required this.retention,
    required this.reviewViews,
    required this.communityResponses,
    required this.upgradeInterest,
  });
}

class PilotCost {
  final int revision, requests, minutes, recordedDays;
  final double modelTwd, storageTwd;
  const PilotCost({
    this.revision = 0,
    this.recordedDays = 0,
    required this.requests,
    required this.minutes,
    required this.modelTwd,
    required this.storageTwd,
  });
}

class PilotMetricsReport {
  final PilotMetrics? metrics;
  final PilotCost costs;
  final bool truncated;
  const PilotMetricsReport({
    required this.metrics,
    required this.costs,
    required this.truncated,
  });
}
