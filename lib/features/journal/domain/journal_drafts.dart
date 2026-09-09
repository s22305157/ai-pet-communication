import 'package:ai_pet_communication/core/storage/account_cleanup.dart';

abstract interface class JournalDrafts implements AccountCleanup {
  Future<Map<String, dynamic>?> read(String uid, String petId, String entryId);
  Future<void> save(
    String uid,
    String petId,
    String entryId,
    Map<String, dynamic> value,
  );
  Future<void> remove(String uid, String petId, String entryId);
}
