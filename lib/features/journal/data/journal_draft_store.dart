import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_pet_communication/core/storage/account_cleanup.dart';

/// All persistence is serialized, scoped by UID, and shared with account cleanup.
class JournalDraftStore implements AccountCleanup {
  Future<void> _queue = Future.value();
  String _prefix(String uid) => 'journalDraft/${Uri.encodeComponent(uid)}/';
  String _key(String uid, String petId, String entryId) =>
      '${_prefix(uid)}$petId/$entryId';
  Future<void> _write(Future<void> Function(SharedPreferences) task) {
    final operation = _queue.then(
      (_) async => task(await SharedPreferences.getInstance()),
    );
    _queue = operation.catchError((Object _) {});
    return operation;
  }

  Future<Map<String, dynamic>?> read(
    String uid,
    String petId,
    String entryId,
  ) async {
    await _queue;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(uid, petId, entryId));
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(
    String uid,
    String petId,
    String entryId,
    Map<String, dynamic> value,
  ) => _write((prefs) async {
    if (!await prefs.setString(_key(uid, petId, entryId), jsonEncode(value))) {
      throw StateError('無法儲存本機草稿');
    }
  });
  Future<void> remove(String uid, String petId, String entryId) =>
      _write((prefs) async {
        await prefs.remove(_key(uid, petId, entryId));
      });
  @override
  Future<void> clearUser(String uid) => _write((prefs) async {
    for (final key in prefs.getKeys().where(
      (key) => key.startsWith(_prefix(uid)),
    )) {
      await prefs.remove(key);
    }
  });
}
