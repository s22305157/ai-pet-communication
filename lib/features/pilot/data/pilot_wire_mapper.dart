import '../domain/pilot_admin.dart';
import 'package:ai_pet_communication/core/data/wire_values.dart';
import '../domain/pilot_request.dart';
import '../domain/pilot_metrics.dart';

(String, Map<String, dynamic>) encodePilotRequest(PilotRequest request) =>
    switch (request) {
      ListPilotNotifications r => (
        'listPilotNotifications',
        {if (r.cursor != null) 'cursor': _cursorMap(r.cursor!)},
      ),
      MarkPilotNotificationRead r => (
        'markPilotNotificationRead',
        {'notificationId': r.notificationId},
      ),
      GetPilotDashboard() => ('adminGetPilotDashboard', {}),
      ListPilotData r => (
        'adminListPilotData',
        {'kind': r.kind, if (r.cursor != null) 'cursor': _cursorMap(r.cursor!)},
      ),
      SetPilotFlags r => ('adminSetPilotFlags', {'flags': r.flags}),
      SetPilotParticipant r => (
        'adminSetPilotParticipant',
        {
          'uid': r.uid,
          'status': r.status,
          'expiresAtMs': r.expiresAtMs,
          'isTest': r.isTest,
        },
      ),
      SetPostingSuspended r => (
        'adminSetPostingSuspended',
        {'uid': r.uid, 'suspended': r.suspended, 'reason': r.reason},
      ),
      ModerateCommunity r => (
        'adminModerateCommunity',
        {
          'reportId': r.reportId,
          'expectedRevision': r.expectedRevision,
          'contentRevision': r.contentRevision,
          'action': r.action,
          'reason': r.reason,
        },
      ),
      GetPilotInterest() => ('getPilotInterest', {}),
      MarkPilotPriceViewed() => ('markPilotPriceViewed', {}),
      SetPilotInterest r => (
        'setPilotInterest',
        {'interested': r.interested, 'priceVersion': 'pilot-twd199-v1'},
      ),
      SetPilotMetricsConsent r => (
        'setPilotMetricsConsent',
        {'enabled': r.enabled},
      ),
      GetPilotMetrics() => ('adminGetPilotMetrics', {}),
      GetPilotCost r => ('adminGetPilotCost', {'day': r.day}),
      SetPilotCost r => (
        'adminSetPilotCost',
        {
          'day': r.day,
          'expectedRevision': r.cost.revision,
          'modelTwd': r.cost.modelTwd,
          'storageTwd': r.cost.storageTwd,
          'requests': r.cost.requests,
          'minutes': r.cost.minutes,
        },
      ),
    };

T decodePilotResponse<T>(PilotRequest<T> request, Map<String, dynamic> data) {
  final Object? value = switch (request) {
    ListPilotNotifications() => PilotNotificationPage(
      items: [
        for (final row in data['items'] as List? ?? [])
          _notification(wireMap(row)),
      ],
      cursor: _cursor(data['cursor']),
    ),
    GetPilotDashboard() => PilotDashboard(
      flags: Map<String, bool>.from(data['flags'] as Map? ?? {}),
      lastSevenDayEvents: (data['lastSevenDayEvents'] as Map? ?? {}).map(
        (key, value) => MapEntry(key as String, (value as num).toInt()),
      ),
      participants: wireInt(data, 'participants'),
      openReports: wireInt(data, 'openReports'),
      suspended: wireInt(data, 'suspended'),
      truncated: data['truncated'] == true,
    ),
    ListPilotData() => PilotAdminPage(
      items: [
        for (final row in data['items'] as List? ?? []) _record(wireMap(row)),
      ],
      cursor: _cursor(data['cursor']),
    ),
    GetPilotInterest() => PilotInterest(
      interested: data['interested'] == true,
      metricsConsent: data['metricsConsent'] == true,
      canExpressInterest: data['canExpressInterest'] == true,
      cleanupPending: data['cleanupPending'] == true,
    ),
    GetPilotCost() => _cost(data),
    GetPilotMetrics() => PilotMetricsReport(
      truncated: data['truncated'] == true,
      costs: _cost(wireMap(data['costs'])),
      metrics: data['truncated'] == true || data['metrics'] == null
          ? null
          : _metrics(wireMap(data['metrics'])),
    ),
    _ => null,
  };
  return value as T;
}

PilotCost _cost(Map data) => PilotCost(
  revision: wireInt(data, 'revision'),
  requests: wireInt(data, 'requests'),
  minutes: wireInt(data, 'minutes'),
  recordedDays: wireInt(data, 'recordedDays'),
  modelTwd: (data['modelTwd'] as num?)?.toDouble() ?? 0,
  storageTwd: (data['storageTwd'] as num?)?.toDouble() ?? 0,
);
PilotRatio _ratio(Object? raw) {
  final data = wireMap(raw);
  return PilotRatio(
    numerator: wireInt(data, 'numerator'),
    denominator: wireInt(data, 'denominator'),
    pending: wireInt(data, 'pending'),
  );
}

PilotMetrics _metrics(Map data) => PilotMetrics(
  fromMs: wireInt(data, 'fromMs'),
  toMs: wireInt(data, 'toMs'),
  measuredParticipants: wireInt(data, 'measuredParticipants'),
  incompleteCohorts: wireInt(data, 'incompleteCohorts'),
  legacyUnlinkedEvents: wireInt(data, 'legacyUnlinkedEvents'),
  activation: _ratio(data['activation']),
  retention: _ratio(data['retention']),
  reviewViews: _ratio(data['reviewViews']),
  communityResponses: _ratio(data['communityResponses']),
  upgradeInterest: _ratio(data['upgradeInterest']),
);

Map<String, dynamic> _cursorMap(PilotCursor cursor) => {
  'id': cursor.id,
  'time': cursor.time,
};
PilotCursor? _cursor(Object? raw) {
  if (raw == null) return null;
  final data = wireMap(raw);
  return PilotCursor(wireId(data), wireInt(data, 'time'));
}

PilotNotification _notification(Map<String, dynamic> row) => PilotNotification(
  id: wireId(row),
  type: wireString(row, 'type'),
  message: wireString(row, 'message'),
  petId: wireString(row, 'petId'),
  week: wireString(row, 'week'),
  postId: row['postId'] as String?,
  read: row['read'] == true,
  count: wireInt(row, 'count'),
);
PilotAdminRecord _record(Map<String, dynamic> row) => PilotAdminRecord(
  id: wireId(row),
  status: wireString(row, 'status'),
  alias: wireString(row, 'alias'),
  text: wireString(row, 'text'),
  postId: wireString(row, 'postId'),
  contentStatus: wireString(row, 'contentStatus'),
  reason: wireString(row, 'reason'),
  action: wireString(row, 'action'),
  actor: wireString(row, 'actor'),
  details: row['details']?.toString() ?? '',
  expiresAtMs: wireInt(row, 'expiresAtMs'),
  createdAtMs: wireInt(row, 'createdAtMs'),
  revision: wireInt(row, 'revision'),
  contentRevision: wireInt(row, 'contentRevision'),
  isTest: row['isTest'] == true,
  postingSuspended: row['postingSuspended'] == true,
  mediaIds: List<String>.from(row['mediaIds'] as List? ?? []),
);
