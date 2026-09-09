import 'package:ai_pet_communication/core/session/current_session.dart';
import 'package:ai_pet_communication/core/session/session_stream.dart';
import 'package:ai_pet_communication/core/storage/storage_policy.dart';
import 'package:ai_pet_communication/features/pet/domain/repositories/owned_pet_lookup.dart';
import 'package:ai_pet_communication/features/readings/domain/reading.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';

import 'package:ai_pet_communication/features/readings/domain/local_readings_store.dart';
import 'package:ai_pet_communication/features/readings/domain/readings_repository.dart';

class AccountReadingsRepository implements ReadingsRepository {
  final CurrentSession _authService;
  final OwnedPetLookup _localPets;
  final LocalReadingsStore _localReadings;
  final ReadingsRepository _cloudReadings;

  AccountReadingsRepository({
    required CurrentSession authService,
    required OwnedPetLookup localPets,
    required LocalReadingsStore localReadings,
    required ReadingsRepository cloudReadings,
  }) : _authService = authService,
       _localPets = localPets,
       _localReadings = localReadings,
       _cloudReadings = cloudReadings;

  Future<({String uid, bool useLocal, bool archive})> _scope(
    String petId,
  ) async {
    final user = await _authService.getUserData();
    if (user == null) throw StateError('Authentication required.');
    if (!const StoragePolicy().usesCloud(user.membershipType)) {
      final pet = await _localPets.getPet(user.uid, petId);
      if (pet == null || pet.ownerId != user.uid) {
        throw StateError('Local pet does not belong to the active user.');
      }
      return (uid: user.uid, useLocal: true, archive: user.canReadCloudArchive);
    }
    return (uid: user.uid, useLocal: false, archive: true);
  }

  Stream<List<Reading>> _combined(String uid, String petId, bool archive) {
    if (!archive) return _localReadings.watchReadings(uid, petId);
    late final StreamController<List<Reading>> controller;
    StreamSubscription<List<Reading>>? localSub;
    StreamSubscription<List<Reading>>? cloudSub;
    var localItems = <Reading>[];
    var cloudItems = <Reading>[];
    var localReady = false;
    var cancelled = false;
    void emit() {
      if (cancelled || !localReady) return;
      final merged = {for (final item in cloudItems) item.id: item};
      for (final item in localItems) {
        final previous = merged[item.id];
        if (previous == null ||
            !(previous.updatedAt ?? previous.createdAt).isAfter(
              item.updatedAt ?? item.createdAt,
            )) {
          merged[item.id] = item;
        }
      }
      controller.add(
        merged.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );
    }

    controller = StreamController<List<Reading>>(
      onListen: () {
        localSub = _localReadings
            .watchReadings(uid, petId)
            .listen(
              (items) {
                localItems = items;
                localReady = true;
                emit();
              },
              onError: (Object error, StackTrace stack) {
                if (!cancelled) controller.addError(error, stack);
              },
            );
        cloudSub = _cloudReadings
            .watchReadingsByPetId(petId)
            .listen(
              (items) {
                cloudItems = items;
                emit();
              },
              onError: (Object error) {
                // Keep local records and the last cloud snapshot during a network outage.
                emit();
              },
            );
      },
      onCancel: () async {
        cancelled = true;
        await Future.wait([
          if (localSub != null) localSub!.cancel(),
          if (cloudSub != null) cloudSub!.cancel(),
        ]);
      },
    );
    return controller.stream;
  }

  @override
  Stream<List<Reading>> watchReadingsByPetId(String petId) async* {
    final scope = await _scope(petId);
    yield* watchSession(
      _authService,
      scope.uid,
      () async => _combined(scope.uid, petId, scope.archive),
      const <Reading>[],
    );
  }

  @override
  Future<Reading?> getReadingById(String petId, String readingId) async {
    final scope = await _scope(petId);
    Reading? result = await _localReadings.getReading(
      scope.uid,
      petId,
      readingId,
    );
    if (scope.archive) {
      try {
        final remote = await _cloudReadings.getReadingById(petId, readingId);
        if (remote != null &&
            (result == null ||
                (remote.updatedAt ?? remote.createdAt).isAfter(
                  result.updatedAt ?? result.createdAt,
                ))) {
          result = remote;
        }
      } on FirebaseException catch (error) {
        if (result == null &&
            error.code != 'permission-denied' &&
            error.code != 'not-found') {
          rethrow;
        }
      }
    }
    if ((await _authService.getUserData())?.uid != scope.uid) {
      throw StateError('Account changed during reading request.');
    }
    return result;
  }

  @override
  Future<void> addReading(Reading reading) async {
    final scope = await _scope(reading.petId);
    if (scope.useLocal) {
      await _localReadings.addReading(scope.uid, reading);
    } else {
      await _cloudReadings.addReading(reading);
    }
  }

  @override
  Future<void> deleteReading(String petId, String readingId) async {
    final scope = await _scope(petId);
    if (scope.archive) {
      try {
        await _cloudReadings.deleteReading(petId, readingId);
      } on FirebaseException catch (error) {
        // A Free local-only pet has no cloud parent. All other failures remain visible.
        if (!scope.useLocal || error.code != 'permission-denied') rethrow;
      }
    }
    await _localReadings.deleteReading(scope.uid, petId, readingId);
  }
}
