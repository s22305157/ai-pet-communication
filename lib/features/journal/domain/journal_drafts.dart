import 'package:ai_pet_communication/core/storage/account_cleanup.dart';

/// A shared instance must order reads, writes, removals and account cleanup in
/// invocation order, across editor lifetimes. Callers enqueue without a private
/// queue so a reopened editor cannot overtake pending writes or removals.
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
