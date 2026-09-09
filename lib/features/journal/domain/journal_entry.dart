class JournalEntry {
  final String id;
  final DateTime occurredAt;
  final String context;
  final String observation;
  final String action;
  final String outcome;
  final List<String> mediaIds;
  final int revision;

  const JournalEntry({
    required this.id,
    required this.occurredAt,
    required this.context,
    required this.observation,
    required this.action,
    required this.outcome,
    required this.mediaIds,
    required this.revision,
  });

  factory JournalEntry.fromMap(Map<String, dynamic> data) => JournalEntry(
    id: data['id'] as String,
    occurredAt: DateTime.fromMillisecondsSinceEpoch(
      data['occurredAtMs'] as int,
    ),
    context: data['context'] as String,
    observation: data['observation'] as String,
    action: data['action'] as String,
    outcome: data['outcome'] as String,
    mediaIds: List<String>.from(data['mediaIds'] as List),
    revision: data['revision'] as int,
  );

  Map<String, dynamic> toInput() => {
    'entryId': id,
    'occurredAtMs': occurredAt.millisecondsSinceEpoch,
    'context': context,
    'observation': observation,
    'action': action,
    'outcome': outcome,
    'mediaIds': mediaIds,
    'expectedRevision': revision,
  };
}

const journalContexts = ['環境適應', '飲食日常', '遊戲互動', '休息', '外出籠', '其他'];
const journalFocuses = ['新貓到家', '熟悉環境', '遊戲互動', '外出籠適應'];
