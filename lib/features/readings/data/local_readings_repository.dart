import 'package:ai_pet_communication/core/storage/account_cleanup.dart';
import 'package:ai_pet_communication/features/readings/domain/local_readings_store.dart';
import 'package:hive/hive.dart';
import 'dart:async';

import 'package:ai_pet_communication/features/readings/domain/reading.dart';

class LocalReadingsRepository
    implements LocalReadingsStore, AccountCleanup, PetReadingsCleanup {
  static const _scopePrefix = 'user/';
  final Box<dynamic> _box;

  LocalReadingsRepository({Box<dynamic>? box})
    : _box = box ?? Hive.box<dynamic>('local_readings');

  String _petPrefix(String uid, String petId) =>
      '$_scopePrefix${Uri.encodeComponent(uid)}/pet/'
      '${Uri.encodeComponent(petId)}/reading/';

  String _key(String uid, String petId, String readingId) =>
      '${_petPrefix(uid, petId)}${Uri.encodeComponent(readingId)}';

  Reading? _decode(dynamic value, String readingId) {
    if (value is! Map) return null;
    try {
      return Reading.fromMap(Map<String, dynamic>.from(value), readingId);
    } catch (_) {
      return null;
    }
  }

  List<Reading> getReadings(String uid, String petId) {
    final prefix = _petPrefix(uid, petId);
    final readings = <Reading>[];
    for (final entry in _box.toMap().entries) {
      final key = entry.key;
      if (key is! String || !key.startsWith(prefix)) continue;
      final encodedId = key.substring(prefix.length);
      final reading = _decode(entry.value, Uri.decodeComponent(encodedId));
      if (reading != null && reading.petId == petId) readings.add(reading);
    }
    readings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return readings;
  }

  @override
  Stream<List<Reading>> watchReadings(String uid, String petId) {
    late final StreamController<List<Reading>> controller;
    StreamSubscription<BoxEvent>? subscription;
    controller = StreamController<List<Reading>>(
      onListen: () {
        subscription = _box.watch().listen((_) {
          controller.add(getReadings(uid, petId));
        }, onError: controller.addError);
        controller.add(getReadings(uid, petId));
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<Reading?> getReading(
    String uid,
    String petId,
    String readingId,
  ) async => _decode(_box.get(_key(uid, petId, readingId)), readingId);

  @override
  Future<void> addReading(String uid, Reading reading) async {
    if (uid.isEmpty || reading.petId.isEmpty || reading.id.isEmpty) {
      throw ArgumentError('uid, petId and readingId are required');
    }
    await _box.put(_key(uid, reading.petId, reading.id), reading.toMap());
  }

  @override
  Future<void> deleteReading(
    String uid,
    String petId,
    String readingId,
  ) async => _box.delete(_key(uid, petId, readingId));

  @override
  Future<void> clearPet(String uid, String petId) async {
    final prefix = _petPrefix(uid, petId);
    final keys = _box.keys
        .where((key) => key is String && key.startsWith(prefix))
        .toList(growable: false);
    await _box.deleteAll(keys);
  }

  @override
  Future<void> clearUser(String uid) async {
    final prefix = '$_scopePrefix${Uri.encodeComponent(uid)}/';
    final keys = _box.keys
        .where((key) => key is String && key.startsWith(prefix))
        .toList(growable: false);
    await _box.deleteAll(keys);
  }
}
