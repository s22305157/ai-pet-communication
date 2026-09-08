import 'package:flutter/foundation.dart';
import 'package:ai_pet_communication/core/storage/mutation_queue.dart';

import 'package:ai_pet_communication/features/pet/data/local_pet_service.dart';
import 'package:ai_pet_communication/features/pet/data/sources/pet_remote_data_source.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';

class SyncState {
  const SyncState({
    this.uid,
    this.isSyncing = false,
    this.isCloudActive = true,
  });
  final String? uid;
  final bool isSyncing;
  final bool isCloudActive;
}

class PetSyncManager {
  final LocalPetService _localService;
  final PetRemoteDataSource _remoteDataSource;
  final MutationQueue _mutations;

  final ValueNotifier<bool> _cloud = ValueNotifier(true);
  final ValueNotifier<bool> _busy = ValueNotifier(false);
  final ValueNotifier<SyncState> _state = ValueNotifier(const SyncState());
  ValueListenable<SyncState> get state => _state;
  ValueListenable<bool> get isCloudActive => _cloud;
  ValueListenable<bool> get isSyncing => _busy;
  final Map<String, Future<void>> _queues = {};
  int _generation = 0;
  String? _activeUid;
  int _listeners = 0;
  void _publish() {
    _state.value = SyncState(
      uid: _activeUid,
      isSyncing: _busy.value,
      isCloudActive: _cloud.value,
    );
  }

  int beginSession(String uid) {
    if (_activeUid == uid) {
      _listeners++;
      return _generation;
    }
    _activeUid = uid;
    _listeners = 1;
    _busy.value = _queues.containsKey(uid);
    _publish();
    return ++_generation;
  }

  bool isCurrentSession(String uid, int generation) =>
      _activeUid == uid && _generation == generation;
  void endSession(String uid, int generation) {
    if (isCurrentSession(uid, generation)) {
      if (--_listeners > 0) return;
      ++_generation;
      _activeUid = null;
      _busy.value = false;
      _publish();
    }
  }

  void reportCloud(String uid, int generation, bool active) {
    if (isCurrentSession(uid, generation)) {
      _cloud.value = active;
      _publish();
    }
  }

  PetSyncManager({
    required LocalPetService localService,
    required PetRemoteDataSource remoteDataSource,
    MutationQueue? mutations,
  }) : _localService = localService,
       _remoteDataSource = remoteDataSource,
       _mutations = mutations ?? MutationQueue();
  Future<void> _enqueue(String uid, Future<void> Function() work) {
    final queued = _mutations.run(uid, work);
    // Store a handled tail so one failure never poisons subsequent work.
    final tail = queued.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _queues[uid] = tail;
    tail.whenComplete(() {
      if (identical(_queues[uid], tail)) {
        _queues.remove(uid);
        if (_activeUid == uid) {
          _busy.value = false;
          _publish();
        }
      }
    });
    if (_activeUid == uid) {
      _busy.value = true;
      _publish();
    }
    return queued;
  }

  void dispose() {
    ++_generation;
    _activeUid = null;
    _cloud.dispose();
    _busy.dispose();
    _state.dispose();
  }

  Future<void> migrateIfNeeded(String uid) => _enqueue(uid, () async {
    try {
      await _localService.migrateLegacyDataForUser(uid);
      await _syncPendingOperations(uid, includeUpserts: true);

      final pendingIds = _localService
          .getPendingOperations(uid)
          .map((operation) => operation.petId)
          .toSet();
      for (final pet in _localService.getAllPets(uid)) {
        if (pet.ownerId != uid || pendingIds.contains(pet.petId)) continue;
        if (await _remoteDataSource.getPetDeletionTime(pet.petId) != null) {
          await _discardDeletedLocalPet(uid, pet);
          continue;
        }

        final cloudPet = await _remoteDataSource.getPet(pet.petId);
        if (cloudPet == null) {
          await _remoteDataSource.setPet(pet.petId, pet);
        } else if (cloudPet.ownerId == uid && resolveConflict(pet, cloudPet)) {
          await _remoteDataSource.updatePet(
            pet.petId,
            pet,
            expectedUpdatedAt: cloudPet.updatedAt,
          );
        } else if (cloudPet.ownerId == uid) {
          await _localService.cacheCloudPet(uid, cloudPet);
        }
      }
    } catch (error) {
      debugPrint('寵物遷移失敗，保留待同步操作: $error');
      rethrow;
    }
  });

  Future<void> syncPendingOperations(
    String uid, {
    bool includeUpserts = true,
  }) => _enqueue(
    uid,
    () => _syncPendingOperations(uid, includeUpserts: includeUpserts),
  );

  Future<void> _syncPendingOperations(
    String uid, {
    required bool includeUpserts,
  }) async {
    for (final operation in _localService.getPendingOperations(uid)) {
      if (operation.ownerId != uid) continue;
      if (operation.isDelete) {
        await _remoteDataSource.deletePet(
          operation.petId,
          avatarUrl: operation.avatarUrl,
        );
        await _localService.clearPendingOperationIfUnchanged(uid, operation);
        continue;
      }
      if (!includeUpserts) continue;

      final pet = operation.pet;
      if (pet == null || pet.ownerId != uid) {
        await _localService.clearPendingOperationIfUnchanged(uid, operation);
        continue;
      }
      if (await _remoteDataSource.getPetDeletionTime(pet.petId) != null) {
        await _discardDeletedLocalPet(uid, pet);
        continue;
      }
      final cloudPet = await _remoteDataSource.getPet(pet.petId);
      if (cloudPet == null) {
        await _remoteDataSource.setPet(pet.petId, pet);
      } else if (cloudPet.ownerId != uid) {
        throw StateError('Remote pet owner does not match pending operation.');
      } else if (resolveConflict(pet, cloudPet)) {
        await _remoteDataSource.updatePet(
          pet.petId,
          pet,
          expectedUpdatedAt: cloudPet.updatedAt,
        );
      } else {
        if (_localService.isPendingOperationCurrent(uid, operation)) {
          await _localService.cacheCloudPet(uid, cloudPet);
        }
      }
      await _localService.clearPendingOperationIfUnchanged(uid, operation);
      await _localService.clearTombstone(uid, pet.petId);
    }
  }

  Future<void> _discardDeletedLocalPet(String uid, PetModel pet) async {
    await _localService.markPendingDelete(
      uid,
      pet.petId,
      avatarUrl: pet.avatarUrl,
    );
    await _localService.clearPendingOperation(uid, pet.petId);
  }

  Future<void> applyCloudSnapshot(String uid, List<PetModel> cloudPets) =>
      _enqueue(uid, () async {
        await _localService.reconcileCloudSnapshot(uid, cloudPets);
        final cloudIds = cloudPets
            .where((pet) => pet.ownerId == uid)
            .map((pet) => pet.petId)
            .toSet();
        final pendingIds = _localService
            .getPendingOperations(uid)
            .map((operation) => operation.petId)
            .toSet();
        for (final localPet in _localService.getAllPets(uid)) {
          if (cloudIds.contains(localPet.petId) ||
              pendingIds.contains(localPet.petId)) {
            continue;
          }
          if (await _remoteDataSource.getPetDeletionTime(localPet.petId) !=
              null) {
            await _discardDeletedLocalPet(uid, localPet);
          }
        }
      });

  bool resolveConflict(PetModel localPet, PetModel cloudPet) {
    final localTime = localPet.updatedAt ?? DateTime(2000);
    final cloudTime = cloudPet.updatedAt ?? DateTime(2000);
    return localTime.isAfter(cloudTime);
  }
}
