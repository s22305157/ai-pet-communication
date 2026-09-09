import 'journal_entry.dart';

class PilotAccess {
  final bool enabled, invited, activated;
  const PilotAccess({
    this.enabled = false,
    this.invited = false,
    this.activated = false,
  });
  factory PilotAccess.fromMap(Map<String, dynamic> m) => PilotAccess(
    enabled: m['enabled'] == true,
    invited: m['invited'] == true,
    activated: m['activated'] == true,
  );
}

class JournalPet {
  final String id, name, species, focus;
  final int entryCount, usedBytes, reservedBytes;
  const JournalPet({
    required this.id,
    required this.name,
    required this.species,
    required this.focus,
    required this.entryCount,
    required this.usedBytes,
    required this.reservedBytes,
  });
  factory JournalPet.fromMap(Map<String, dynamic> m) => JournalPet(
    id: m['id'] as String,
    name: m['name'] as String,
    species: m['species'] as String? ?? '',
    focus: m['focus'] as String? ?? '',
    entryCount: (m['entryCount'] as num?)?.toInt() ?? 0,
    usedBytes: (m['usedBytes'] as num?)?.toInt() ?? 0,
    reservedBytes: (m['reservedBytes'] as num?)?.toInt() ?? 0,
  );
}

class JournalHome {
  final JournalPet? pet;
  final int weekDays;
  const JournalHome(this.pet, this.weekDays);
  factory JournalHome.fromMap(Map<String, dynamic> m) => JournalHome(
    m['pet'] == null
        ? null
        : JournalPet.fromMap(Map<String, dynamic>.from(m['pet'] as Map)),
    (m['weekDays'] as num?)?.toInt() ?? 0,
  );
}

class JournalCursor {
  final int time;
  final String id;
  const JournalCursor(this.time, this.id);
  factory JournalCursor.fromMap(Map<String, dynamic> m) =>
      JournalCursor(m['time'] as int, m['id'] as String);
  Map<String, dynamic> toMap() => {'time': time, 'id': id};
}

class JournalPage {
  final List<JournalEntry> items;
  final JournalCursor? cursor;
  const JournalPage(this.items, this.cursor);
  factory JournalPage.fromMap(Map<String, dynamic> m) => JournalPage(
    (m['items'] as List)
        .map((e) => JournalEntry.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList(),
    m['cursor'] == null
        ? null
        : JournalCursor.fromMap(Map<String, dynamic>.from(m['cursor'] as Map)),
  );
}

class JournalPetInput {
  final String name, species, focus;
  final DateTime? arrivedAt;
  const JournalPetInput({
    required this.name,
    required this.species,
    required this.focus,
    this.arrivedAt,
  });
  Map<String, dynamic> toMap() => {
    'name': name,
    'species': species,
    'focus': focus,
    'arrivedAtMs': arrivedAt?.millisecondsSinceEpoch,
  };
}

class JournalEntryInput {
  final String petId, operationId;
  final JournalEntry entry;
  const JournalEntryInput({
    required this.petId,
    required this.operationId,
    required this.entry,
  });
  Map<String, dynamic> toMap() => {
    'petId': petId,
    'operationId': operationId,
    ...entry.toInput(),
  };
}
