import 'package:ai_pet_communication/core/domain/app_request.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ai_pet_communication/core/errors/service_failure.dart';
import 'package:uuid/uuid.dart';
import 'package:ai_pet_communication/core/domain/request_repository.dart';

typedef RequestLoader<T> = Future<T> Function();

class RequestController<T> extends ChangeNotifier {
  final RequestRepository repository;
  final RequestLoader<T> loader;
  T? value;
  String? error;
  bool busy = false, expired = false, _disposed = false;
  int _generation = 0;
  final Map<String, String> _pending = {};
  late final StreamSubscription<bool> _session;
  RequestController(this.repository, this.loader) {
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

  Future<bool> submit(AppRequest<void> request) => _mutate(
    repository.requestKey(request),
    (id) => repository.execute(request, operationId: id),
  );

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
        if (e is ServiceFailure && !e.preservesOperationId) {
          _pending.remove(key);
        }
        if (e is ServiceFailure &&
            (e.isSessionFailure || e.kind == FailureKind.notFound)) {
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
  if (e is ServiceFailure) return e.message ?? '服務暫時無法使用，請稍後重試';
  if (e is StateError) return e.message.toString();
  return '連線或服務暫時無法使用，請稍後重試';
}
