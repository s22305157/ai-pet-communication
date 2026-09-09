import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../domain/journal_repository.dart';

class FirebaseJournalRepository implements JournalRepository {
  @override
  final String uid;
  final FirebaseAuth auth;
  final FirebaseFunctions functions;
  FirebaseJournalRepository({
    required this.uid,
    required this.auth,
    required this.functions,
  });

  @override
  bool get isCurrentSession => auth.currentUser?.uid == uid;
  void _check() {
    if (!isCurrentSession) throw StateError('帳號已變更，請重新進入日記');
  }

  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    _check();
    final result = await functions
        .httpsCallable(
          action,
          options: HttpsCallableOptions(timeout: const Duration(seconds: 65)),
        )
        .call<Map<String, dynamic>>({
          'operationId': const Uuid().v4(),
          ...data,
        });
    _check();
    return Map<String, dynamic>.from(result.data);
  }

  @override
  Future<String> upload(
    String petId,
    Uint8List bytes,
    String contentType,
  ) async {
    _check();
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw StateError('照片不得超過 10 MiB');
    }
    final pending = await call('beginJournalUpload', {
      'petId': petId,
      'bytes': bytes.length,
      'contentType': contentType,
    });
    _check();
    try {
      await call('uploadJournalBytes', {
        'mediaId': pending['mediaId'],
        'base64': base64Encode(bytes),
      });
      _check();
      final result = await call('finalizeJournalUpload', {
        'mediaId': pending['mediaId'],
      });
      return result['mediaId'] as String;
    } catch (_) {
      // Best effort release; the server sweeper covers offline failures.
      if (isCurrentSession) {
        try {
          await call('cancelJournalUpload', {'mediaId': pending['mediaId']});
        } catch (_) {}
      }
      rethrow;
    }
  }

  @override
  Future<Uint8List> image(String mediaId) async {
    _check();
    final result = await call('getJournalImage', {'mediaId': mediaId});
    _check();
    return base64Decode(result['base64'] as String);
  }
}
