import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/journal_drafts.dart';

/// Mobile uses OS protected storage; web uses WebCrypto on HTTPS.
/// Web encryption does not protect against same-origin scripts.
class JournalDraftStore implements JournalDrafts {
  JournalDraftStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  Future<void> _queue = Future.value();
  String _prefix(String uid) => 'journalDraft/${Uri.encodeComponent(uid)}/';
  String _key(String uid, String petId, String entryId) =>
      '${_prefix(uid)}$petId/$entryId';
  Future<T> _serialize<T>(Future<T> Function() task) {
    final operation = _queue.then((_) => task());
    _queue = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  Future<void> _migrate(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key
        in prefs.getKeys().where((k) => k.startsWith(_prefix(uid))).toList()) {
      final old = prefs.getString(key);
      if (old != null && await _storage.read(key: key) == null) {
        await _storage.write(key: key, value: old);
        if (await _storage.read(key: key) != old) {
          throw StateError('草稿加密移轉未完成，原草稿仍保留');
        }
      }
      await prefs.remove(key);
    }
  }

  @override
  Future<Map<String, dynamic>?> read(
    String uid,
    String petId,
    String entryId,
  ) => _serialize(() async {
    await _migrate(uid);
    final raw = await _storage.read(key: _key(uid, petId, entryId));
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  });
  @override
  Future<void> save(
    String uid,
    String petId,
    String entryId,
    Map<String, dynamic> value,
  ) => _serialize(() async {
    await _migrate(uid);
    await _storage.write(
      key: _key(uid, petId, entryId),
      value: jsonEncode(value),
    );
  });
  @override
  Future<void> remove(String uid, String petId, String entryId) =>
      _serialize(() async {
        await _migrate(uid);
        await _storage.delete(key: _key(uid, petId, entryId));
      });
  @override
  Future<void> clearUser(String uid) => _serialize(() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key
        in prefs.getKeys().where((k) => k.startsWith(_prefix(uid))).toList()) {
      await prefs.remove(key);
    }
    for (final key
        in (await _storage.readAll()).keys
            .where((k) => k.startsWith(_prefix(uid)))
            .toList()) {
      await _storage.delete(key: key);
    }
  });
}
