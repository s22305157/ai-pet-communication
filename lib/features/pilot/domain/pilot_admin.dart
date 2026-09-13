class PilotCursor {
  final String id;
  final int time;
  const PilotCursor(this.id, this.time);
}

class PilotNotification {
  final String id, type, message, petId, week;
  final String? postId;
  final bool read;
  final int count;
  const PilotNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.petId,
    required this.week,
    this.postId,
    required this.read,
    required this.count,
  });
}

class PilotNotificationPage {
  final List<PilotNotification> items;
  final PilotCursor? cursor;
  PilotNotificationPage({required List<PilotNotification> items, this.cursor})
    : items = List.unmodifiable(items);
}

class PilotDashboard {
  final Map<String, bool> flags;
  final Map<String, int> lastSevenDayEvents;
  final int participants, openReports, suspended;
  final bool truncated;
  PilotDashboard({
    required Map<String, bool> flags,
    required Map<String, int> lastSevenDayEvents,
    required this.participants,
    required this.openReports,
    required this.suspended,
    required this.truncated,
  }) : flags = Map.unmodifiable(flags),
       lastSevenDayEvents = Map.unmodifiable(lastSevenDayEvents);
}

class PilotAdminRecord {
  final String id,
      status,
      alias,
      text,
      postId,
      contentStatus,
      reason,
      action,
      actor,
      details;
  final int expiresAtMs, createdAtMs, revision, contentRevision;
  final bool isTest, postingSuspended;
  final List<String> mediaIds;
  PilotAdminRecord({
    required this.id,
    required this.status,
    required this.alias,
    required this.text,
    required this.postId,
    required this.contentStatus,
    required this.reason,
    required this.action,
    required this.actor,
    required this.details,
    required this.expiresAtMs,
    required this.createdAtMs,
    required this.revision,
    required this.contentRevision,
    required this.isTest,
    required this.postingSuspended,
    required List<String> mediaIds,
  }) : mediaIds = List.unmodifiable(mediaIds);
}

class PilotAdminPage {
  final List<PilotAdminRecord> items;
  final PilotCursor? cursor;
  PilotAdminPage({required List<PilotAdminRecord> items, this.cursor})
    : items = List.unmodifiable(items);
}

class PilotAdminView {
  final PilotDashboard dashboard;
  final PilotAdminPage page;
  const PilotAdminView(this.dashboard, this.page);
}
