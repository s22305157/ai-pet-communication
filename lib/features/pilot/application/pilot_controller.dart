import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';
import '../domain/pilot_repository.dart';
import '../domain/pilot_request.dart';

typedef PilotLoader<T> = Future<T> Function();

class PilotController<T> extends ChangeNotifier {
  final PilotRepository repository;
  final PilotLoader<T> loader;
  T? value;
  // Compatibility for the existing administrative screens.
  Map<String, dynamic> get data =>
      value is Map<String, dynamic> ? value as Map<String, dynamic> : const {};
  String? error;
  bool busy = false, expired = false, _disposed = false;
  int _generation = 0;
  final Map<String, String> _pending = {};
  late final StreamSubscription<bool> _session;
  PilotController(this.repository, this.loader) {
    _session = repository.sessionChanges.listen((current) {
      if (!current) {
        expired = true;
        ++_generation;
        value = null;
        _pending.clear();
        error = '帳號已變更，請返回首頁';
        busy = false;
        notifyListeners();
      }
    });
  }
  bool get current => !_disposed && !expired && repository.isCurrentSession;
  Future<void> load() async {
    if (!current || busy) return;
    final generation = ++_generation;
    busy = true;
    error = null;
    value = null;
    notifyListeners();
    try {
      final result = await loader();
      if (current && generation == _generation) value = result;
    } catch (e) {
      if (current) error = pilotError(e);
    } finally {
      if (current) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<bool> submit(PilotRequest<void> request) => _mutate(
    repository.requestKey(request),
    (id) => repository.execute(request, operationId: id),
  );

  Future<bool> mutate(String name, Map<String, dynamic> values) =>
      _mutate(jsonEncode([name, values]), (id) async {
        await repository.call(name, {...values, 'operationId': id});
      });

  Future<bool> _mutate(String key, Future<void> Function(String) send) async {
    if (!current || busy) return false;
    final operation = _pending.putIfAbsent(key, () => const Uuid().v4());
    busy = true;
    error = null;
    notifyListeners();
    var success = false;
    try {
      await send(operation);
      if (current) {
        _pending.remove(key);
        success = true;
      }
    } catch (e) {
      if (current) {
        error = pilotError(e);
        // Keep ambiguous network failures retryable with the same operation ID.
        if (e is FirebaseFunctionsException &&
            ![
              'unavailable',
              'deadline-exceeded',
              'internal',
            ].contains(e.code)) {
          _pending.remove(key);
        }
        if (e is FirebaseFunctionsException &&
            [
              'permission-denied',
              'not-found',
              'unauthenticated',
            ].contains(e.code)) {
          value = null;
        }
      }
    } finally {
      if (current) {
        busy = false;
        notifyListeners();
      }
    }
    if (success) await load();
    return success;
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _session.cancel();
    _pending.clear();
    value = null;
    super.dispose();
  }
}

String pilotError(Object e) {
  if (e is FirebaseFunctionsException) return e.message ?? '服務暫時無法使用，請稍後重試';
  if (e is StateError) return e.message.toString();
  return '連線或服務暫時無法使用，請稍後重試';
}
