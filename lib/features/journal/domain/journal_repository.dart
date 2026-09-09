import 'dart:typed_data';
import 'journal_contract.dart';
export 'journal_contract.dart';

typedef JournalPetBasics =
    List<({String name, String species})> Function(String uid);

abstract interface class JournalRepository {
  String get uid;
  bool get isCurrentSession;
  Future<PilotAccess> getPilotAccess();
  Future<JournalHome> getJournalHome();
  Future<JournalPage> listEntries({
    required String petId,
    String? context,
    DateTime? from,
    DateTime? to,
    JournalCursor? cursor,
  });
  Future<void> activatePilot({required bool metricsConsent});
  Future<void> createPet(JournalPetInput input);
  Future<void> saveEntry(JournalEntryInput input);
  Future<void> deleteEntry({
    required String petId,
    required String entryId,
    required int expectedRevision,
  });
  Future<void> deletePet(String petId);
  Future<Map<String, dynamic>> exportJournal(String petId);
  Future<String> upload(String petId, Uint8List bytes, String contentType);
  Future<Uint8List> image(String mediaId);
}
