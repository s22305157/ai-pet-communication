import 'dart:async';
import 'package:ai_pet_communication/core/storage/mutation_queue.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_write_result.dart';
import 'package:flutter/foundation.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/features/pet/domain/repositories/pet_repository.dart';
import 'package:ai_pet_communication/features/pet/data/local_pet_service.dart';
import 'package:ai_pet_communication/features/pet/data/sources/pet_remote_data_source.dart';
import 'package:ai_pet_communication/core/session/current_session.dart';
import 'package:ai_pet_communication/core/storage/storage_policy.dart';

class PetRepositoryImpl implements PetRepository {
  final DateTime Function() _clock;
  final PetRemoteDataSource _remoteDataSource;
  final LocalPetService _localService;
  final CurrentSession _authService;
  final MutationQueue _mutations;

  PetRepositoryImpl({
    DateTime Function()? clock,
    required PetRemoteDataSource remoteDataSource,
    required LocalPetService localService,
    required CurrentSession authService,
    MutationQueue? mutations,
  }) : _clock = clock ?? DateTime.now,
       _remoteDataSource = remoteDataSource,
       _localService = localService,
       _authService = authService,
       _mutations = mutations ?? MutationQueue();

  @override
  Future<bool> shouldUseCloud() async {
    final userModel = await _authService.getUserData();
    return userModel != null &&
        const StoragePolicy().usesCloud(userModel.membershipType);
  }

  @override
  Future<PetModel?> getPet(String petId) async {
    final user = await _authService.getUserData();
    if (user == null) return null;

    try {
      if (const StoragePolicy().usesCloud(user.membershipType)) {
        final pet = await _remoteDataSource.getPet(petId);
        if (pet != null && pet.ownerId == user.uid) {
          if ((await _authService.getUserData())?.uid != user.uid) return null;
          return pet;
        }
      }
    } catch (e) {
      debugPrint('雲端 getPet 失敗: $e');
    }
    final pet = await _localService.getPet(user.uid, petId);
    return (await _authService.getUserData())?.uid == user.uid ? pet : null;
  }

  @override
  Future<PetWriteResult> createPet(PetModel pet) =>
      _mutations.run(pet.ownerId, () => _createPet(pet));
  Future<PetWriteResult> _createPet(PetModel pet) async {
    final user = await _authService.getUserData();
    if (user == null) throw PetWriteFailure('Authentication required.');
    if (pet.ownerId != user.uid) {
      throw PetWriteFailure('Pet owner does not match the active user.');
    }

    final petId = pet.petId.isEmpty ? const Uuid().v4() : pet.petId;
    final now = _clock();
    final petWithId = pet.copyWith(
      petId: petId,
      createdAt: pet.createdAt ?? now,
      updatedAt: pet.updatedAt ?? now,
    );
    final pendingToken = _localService.pendingToken(user.uid, petId);

    if (const StoragePolicy().usesCloud(user.membershipType)) {
      try {
        await _remoteDataSource.setPet(petId, petWithId);
        if (_localService.pendingToken(user.uid, petId) != pendingToken) {
          return PetWriteResult.pendingSync;
        }
        await _localService.clearPendingOperation(user.uid, petId);
      } catch (e) {
        if (e is PetVersionConflict) return PetWriteResult.conflict;
        if (!_isRetryable(e)) rethrow;
        if (_localService.pendingToken(user.uid, petId) != pendingToken) {
          return PetWriteResult.pendingSync;
        }
        debugPrint('建立寵物雲端同步失敗，已加入待同步佇列: $e');
        await _localService.updatePet(user.uid, petId, petWithId);
        final stored = await _localService.getPet(user.uid, petId);
        if (stored != null) {
          await _localService.markPendingUpsert(user.uid, stored);
        }
        return PetWriteResult.pendingSync;
      }
    }
    await _localService.updatePet(user.uid, petId, petWithId);
    return PetWriteResult.saved;
  }

  @override
  Future<PetWriteResult> updatePet(String petId, PetModel pet) =>
      _mutations.run(pet.ownerId, () => _updatePet(petId, pet));
  Future<PetWriteResult> _updatePet(String petId, PetModel pet) async {
    final user = await _authService.getUserData();
    if (user == null) throw PetWriteFailure('Authentication required.');
    if (pet.ownerId != user.uid) {
      throw PetWriteFailure('Pet owner does not match the active user.');
    }
    final cachedPet = await _localService.getPet(user.uid, petId);
    final pendingToken = _localService.pendingToken(user.uid, petId);
    final versionedPet = pet.copyWith(
      createdAt: pet.createdAt ?? cachedPet?.createdAt,
      updatedAt: _clock(),
    );

    if (const StoragePolicy().usesCloud(user.membershipType)) {
      try {
        final remotePet = await _remoteDataSource.getPet(petId);
        if (remotePet != null) {
          if (remotePet.ownerId != user.uid) {
            throw PetWriteFailure(
              'Remote pet owner does not match the active user.',
            );
          }
          if (remotePet.updatedAt != null && pet.updatedAt != null) {
            if (remotePet.updatedAt!.isAfter(pet.updatedAt!)) {
              debugPrint('衝突：雲端資料較新。改為將雲端資料同步至本地。');
              if (_localService.pendingToken(user.uid, petId) == pendingToken) {
                await _localService.updatePet(user.uid, petId, remotePet);
              }
              return PetWriteResult.conflict;
            }
          }
        }
        await _remoteDataSource.updatePet(
          petId,
          versionedPet,
          expectedUpdatedAt: remotePet?.updatedAt,
        );
        if (_localService.pendingToken(user.uid, petId) != pendingToken) {
          return PetWriteResult.pendingSync;
        }
        await _localService.clearPendingOperation(user.uid, petId);
      } catch (e) {
        if (e is PetVersionConflict) return PetWriteResult.conflict;
        if (!_isRetryable(e)) rethrow;
        if (_localService.pendingToken(user.uid, petId) != pendingToken) {
          return PetWriteResult.pendingSync;
        }
        debugPrint('更新寵物雲端同步失敗，已加入待同步佇列: $e');
        await _localService.updatePet(user.uid, petId, versionedPet);
        final stored = await _localService.getPet(user.uid, petId);
        if (stored != null) {
          await _localService.markPendingUpsert(user.uid, stored);
        }
        return PetWriteResult.pendingSync;
      }
    }
    await _localService.updatePet(user.uid, petId, versionedPet);
    return PetWriteResult.saved;
  }

  @override
  Future<PetWriteResult> deletePet(
    String petId, {
    String? expectedOwnerId,
  }) async {
    final user = await _authService.getUserData();
    if (user == null) throw PetWriteFailure('Authentication required.');
    if (expectedOwnerId != null && expectedOwnerId != user.uid) {
      throw const PetWriteFailure('帳號已變更');
    }
    return _mutations.run(user.uid, () => _deletePet(petId, user.uid));
  }

  Future<PetWriteResult> _deletePet(String petId, String expectedUid) async {
    final user = await _authService.getUserData();
    if (user == null || user.uid != expectedUid) {
      throw PetWriteFailure('Authentication required.');
    }

    final localPet = await _localService.getPet(user.uid, petId);
    var pending = false;
    try {
      await _remoteDataSource.deletePet(petId, avatarUrl: localPet?.avatarUrl);
    } catch (error) {
      if (!_isRetryable(error)) rethrow;
      pending = true;
    }
    await _localService.markPendingDelete(
      user.uid,
      petId,
      avatarUrl: localPet?.avatarUrl,
    );
    if (!pending) await _localService.clearPendingOperation(user.uid, petId);
    return pending ? PetWriteResult.pendingSync : PetWriteResult.saved;
  }
}

bool _isRetryable(Object error) =>
    error is TimeoutException ||
    (error is FirebaseException &&
        const [
          'unavailable',
          'deadline-exceeded',
          'network-request-failed',
          'aborted',
        ].contains(error.code));
