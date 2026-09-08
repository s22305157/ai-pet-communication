import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../data/local_pet_service.dart';
import '../data/sources/pet_remote_data_source.dart';
import '../domain/models/pet_model.dart';

class PetSyncManager {
  final LocalPetService _localService;
  final PetRemoteDataSource _remoteDataSource;

  final ValueNotifier<bool> isCloudActive = ValueNotifier<bool>(true);
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);

  PetSyncManager({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    LocalPetService? localService,
    PetRemoteDataSource? remoteDataSource,
  }) : _localService = localService ?? LocalPetService(),
       _remoteDataSource =
           remoteDataSource ??
           PetRemoteDataSource(firestore: firestore, storage: storage);

  Future<void> migrateIfNeeded(String uid) async {
    if (isSyncing.value) return;
    isSyncing.value = true;
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
          await _remoteDataSource.updatePet(pet.petId, pet);
        } else if (cloudPet.ownerId == uid) {
          await _localService.cacheCloudPet(uid, cloudPet);
        }
      }
    } catch (error) {
      debugPrint('寵物遷移失敗，保留待同步操作: $error');
      rethrow;
    } finally {
      isSyncing.value = false;
    }
  }

  Future<void> syncPendingOperations(
    String uid, {
    bool includeUpserts = true,
  }) async {
    if (isSyncing.value) return;
    isSyncing.value = true;
    try {
      await _syncPendingOperations(uid, includeUpserts: includeUpserts);
    } finally {
      isSyncing.value = false;
    }
  }

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
        await _localService.clearPendingOperation(uid, operation.petId);
        continue;
      }
      if (!includeUpserts) continue;

      final pet = operation.pet;
      if (pet == null || pet.ownerId != uid) {
        await _localService.clearPendingOperation(uid, operation.petId);
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
        await _remoteDataSource.updatePet(pet.petId, pet);
      } else {
        await _localService.cacheCloudPet(uid, cloudPet);
      }
      await _localService.clearPendingOperation(uid, pet.petId);
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

  Future<void> applyCloudSnapshot(String uid, List<PetModel> cloudPets) async {
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
      if (await _remoteDataSource.getPetDeletionTime(localPet.petId) != null) {
        await _discardDeletedLocalPet(uid, localPet);
      }
    }
  }

  bool resolveConflict(PetModel localPet, PetModel cloudPet) {
    final localTime = localPet.updatedAt ?? DateTime(2000);
    final cloudTime = cloudPet.updatedAt ?? DateTime(2000);
    return localTime.isAfter(cloudTime);
  }
}
