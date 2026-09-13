import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:ai_pet_communication/core/errors/service_failure.dart';
import '../domain/journal_drafts.dart';
import '../domain/journal_entry.dart';
import '../domain/journal_repository.dart';
import 'journal_controller.dart';

class JournalEditorController extends ChangeNotifier {
  final JournalRepository repository;
  final JournalDrafts drafts;
  final String petId;
  final JournalEntry? original;
  late String entryId = original?.id ?? const Uuid().v4();
  late int revision = original?.revision ?? 0;
  String operationId = const Uuid().v4();
  String context = journalContexts.first;
  DateTime occurredAt = DateTime.now();
  String observation = '', action = '', outcome = '';
  final List<String> _mediaIds = [];
  List<String> get mediaIds => List.unmodifiable(_mediaIds);
  bool busy = false, loading = true, dirty = false, conflict = false;
  String? error;
  String status = '草稿加密保存在裝置，登出會清除；共用裝置請記得登出';
  bool _disposed = false;
  int _generation = 0;
  Future<void> _draftWrites = Future.value();
  String get _draftKey => original?.id ?? 'new';
  bool get current => !_disposed && repository.isCurrentSession;

  JournalEditorController({
    required this.repository,
    required this.drafts,
    required this.petId,
    this.original,
  });

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  JournalEntryInput _input() => JournalEntryInput(
    petId: petId,
    operationId: operationId,
    entry: JournalEntry(
      id: entryId,
      occurredAt: occurredAt,
      context: context,
      observation: observation,
      action: action,
      outcome: outcome,
      mediaIds: List.of(_mediaIds),
      revision: revision,
    ),
  );

  Future<void> restore() async {
    try {
      final draft = await drafts.read(repository.uid, petId, _draftKey);
      if (!current) return;
      final data = draft ?? original?.toInput();
      if (data != null) {
        observation = data['observation'] as String? ?? '';
        action = data['action'] as String? ?? '';
        outcome = data['outcome'] as String? ?? '';
        entryId = data['entryId'] as String? ?? entryId;
        revision = data['expectedRevision'] as int? ?? revision;
        context = data['context'] as String? ?? journalContexts.first;
        occurredAt = DateTime.fromMillisecondsSinceEpoch(
          data['occurredAtMs'] as int,
        );
        _mediaIds.addAll(List<String>.from(data['mediaIds'] as List? ?? []));
        operationId = data['operationId'] as String? ?? operationId;
        dirty = draft != null;
        conflict =
            draft != null && original != null && revision != original!.revision;
        if (draft != null) status = '已還原本機草稿・尚未同步';
      }
    } catch (_) {
      if (current) error = '無法讀取本機草稿';
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> _persist(Map<String, dynamic> snapshot) {
    final write = _draftWrites.then((_) async {
      if (repository.isCurrentSession) {
        await drafts.save(repository.uid, petId, _draftKey, snapshot);
      }
    });
    _draftWrites = write.catchError((Object _) {});
    return write;
  }

  void changed({
    required String observation,
    required String action,
    required String outcome,
  }) {
    if (!current || loading || busy) return;
    this.observation = observation;
    this.action = action;
    this.outcome = outcome;
    _changed();
  }

  void _changed() {
    final generation = ++_generation;
    operationId = const Uuid().v4();
    dirty = true;
    status = '尚未同步・正在保留文字草稿';
    _notify();
    unawaited(
      _persist(_input().toMap())
          .then((_) {
            if (current && generation == _generation) {
              status = '尚未同步・文字草稿已保留在這個裝置';
              _notify();
            }
          })
          .catchError((Object _) {
            if (current && generation == _generation) {
              status = '本機空間不足，草稿尚未保存，請勿關閉';
              _notify();
            }
          }),
    );
  }

  void removePhoto(String id) {
    if (!current || busy) return;
    _mediaIds.remove(id);
    _changed();
  }

  Future<void> addPhoto(Future<Uint8List?> Function() pick) async {
    if (!current || busy || loading || _mediaIds.length >= 3) return;
    busy = true;
    error = null;
    _notify();
    try {
      final bytes = await pick();
      if (bytes == null || !current) return;
      if (bytes.length > 10 * 1024 * 1024) throw StateError('照片不得超過 10 MiB');
      final png =
          bytes.length >= 8 &&
          bytes[0] == 137 &&
          bytes[1] == 80 &&
          bytes[2] == 78 &&
          bytes[3] == 71;
      final jpeg =
          bytes.length >= 3 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255;
      if (!png && !jpeg) throw StateError('請選擇 JPEG 或 PNG 照片');
      final id = await repository.upload(
        petId,
        bytes,
        png ? 'image/png' : 'image/jpeg',
      );
      if (!current) return;
      _mediaIds.add(id);
      _changed();
    } catch (e) {
      if (current) error = journalError(e);
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> save() async {
    if (!current || busy || loading || conflict) return false;
    if (observation.trim().isEmpty &&
        action.trim().isEmpty &&
        outcome.trim().isEmpty &&
        _mediaIds.isEmpty) {
      error = '請至少加入文字或一張照片';
      _notify();
      return false;
    }
    busy = true;
    error = null;
    _notify();
    final input = _input();
    try {
      await _persist(input.toMap());
      if (!current) return false;
      await repository.saveEntry(input);
      if (!current) return false;
      await drafts.remove(repository.uid, petId, _draftKey);
      dirty = false;
      return current;
    } catch (e) {
      if (current) {
        error = journalError(e);
        conflict = e is ServiceFailure && e.kind == FailureKind.conflict;
      }
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> discard() async {
    if (!current || busy) return;
    busy = true;
    ++_generation;
    _notify();
    try {
      await _draftWrites;
      if (current) await drafts.remove(repository.uid, petId, _draftKey);
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    super.dispose();
  }
}
