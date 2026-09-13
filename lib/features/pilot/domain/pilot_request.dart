import 'package:ai_pet_communication/core/domain/app_request.dart';
import 'pilot_metrics.dart';
import 'pilot_admin.dart';

sealed class PilotRequest<T> extends AppRequest<T> {
  const PilotRequest();
}

final class ListPilotNotifications extends PilotRequest<PilotNotificationPage> {
  final PilotCursor? cursor;
  const ListPilotNotifications({this.cursor});
}

final class MarkPilotNotificationRead extends PilotRequest<void> {
  final String notificationId;
  const MarkPilotNotificationRead(this.notificationId);
}

final class GetPilotDashboard extends PilotRequest<PilotDashboard> {
  const GetPilotDashboard();
}

final class ListPilotData extends PilotRequest<PilotAdminPage> {
  final String kind;
  final PilotCursor? cursor;
  const ListPilotData({required this.kind, this.cursor});
}

final class SetPilotFlags extends PilotRequest<void> {
  final Map<String, bool> flags;
  SetPilotFlags(Map<String, bool> flags) : flags = Map.unmodifiable(flags);
}

final class SetPilotParticipant extends PilotRequest<void> {
  final String uid, status;
  final int expiresAtMs;
  final bool isTest;
  const SetPilotParticipant({
    required this.uid,
    required this.status,
    required this.expiresAtMs,
    required this.isTest,
  });
}

final class SetPostingSuspended extends PilotRequest<void> {
  final String uid, reason;
  final bool suspended;
  const SetPostingSuspended({
    required this.uid,
    required this.reason,
    required this.suspended,
  });
}

final class ModerateCommunity extends PilotRequest<void> {
  final String reportId, action, reason;
  final int expectedRevision, contentRevision;
  const ModerateCommunity({
    required this.reportId,
    required this.action,
    required this.reason,
    required this.expectedRevision,
    required this.contentRevision,
  });
}

final class GetPilotInterest extends PilotRequest<PilotInterest> {
  const GetPilotInterest();
}

final class MarkPilotPriceViewed extends PilotRequest<void> {
  const MarkPilotPriceViewed();
}

final class SetPilotInterest extends PilotRequest<void> {
  final bool interested;
  const SetPilotInterest(this.interested);
}

final class SetPilotMetricsConsent extends PilotRequest<void> {
  final bool enabled;
  const SetPilotMetricsConsent(this.enabled);
}

final class GetPilotMetrics extends PilotRequest<PilotMetricsReport> {
  const GetPilotMetrics();
}

final class GetPilotCost extends PilotRequest<PilotCost> {
  final String day;
  const GetPilotCost(this.day);
}

final class SetPilotCost extends PilotRequest<void> {
  final String day;
  final PilotCost cost;
  const SetPilotCost(this.day, this.cost);
}
