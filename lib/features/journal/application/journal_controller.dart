import 'package:flutter/foundation.dart';
import '../domain/journal_entry.dart';
import '../domain/journal_repository.dart';

class JournalController extends ChangeNotifier {
  final JournalRepository repository;
  JournalController(this.repository);
  PilotAccess? access;
  JournalPet? pet;
  List<JournalEntry> entries = [];
  JournalCursor? cursor;
  int weekDays = 0;
  String? latestReviewWeek;
  String? contextFilter;
  DateTime? from;
  DateTime? to;
  bool busy = false;
  String? error;
  bool _disposed = false;
  int _generation = 0;
  bool get canWrite =>
      access?.invited == true &&
      access?.enabled == true &&
      access?.activated == true;

  bool _current(int generation) =>
      !_disposed && generation == _generation && repository.isCurrentSession;
  Future<void> load({bool more = false}) async {
    final generation = ++_generation;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final newAccess = await repository.getPilotAccess();
      final home = await repository.getJournalHome();
      if (!_current(generation)) return;
      access = newAccess;
      pet = home.pet;
      weekDays = home.weekDays;
      latestReviewWeek = home.latestReviewWeek;
      if (pet != null) {
        final result = await repository.listEntries(
          petId: pet!.id,
          context: contextFilter,
          from: from,
          to: to == null
              ? null
              : (to!.isAfter(DateTime.now()) ? DateTime.now() : to),
          cursor: more ? cursor : null,
        );
        if (!_current(generation)) return;
        entries = more ? [...entries, ...result.items] : result.items;
        cursor = result.cursor;
      } else {
        entries = [];
        cursor = null;
      }
    } catch (e) {
      if (_current(generation)) error = journalError(e);
    } finally {
      if (_current(generation)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    super.dispose();
  }
}

String journalError(Object error) {
  // FirebaseFunctionsException messages originate from the sanitized backend.
  final message = error.toString();
  if (message.contains('permission-denied')) return '此帳號目前無法寫入日記，請確認試營運資格。';
  if (message.contains('aborted')) return '雲端已有新版本，請重新載入後再編輯；本機草稿已保留。';
  if (message.contains('resource-exhausted')) {
    return '已達使用量上限或操作太頻繁；草稿已保留，請稍後重試。';
  }
  if (message.contains('unavailable') ||
      message.contains('deadline-exceeded')) {
    return '連線或服務暫時無法使用；文字草稿已保留在這個裝置。';
  }
  if (error is StateError) return error.message.toString();
  return '操作未完成，請檢查輸入或稍後重試；草稿已保留。';
}
