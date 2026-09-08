import 'dart:async';
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

  PetRepositoryImpl({
    DateTime Function()? clock,
    required PetRemoteDataSource remoteDataSource,
    required LocalPetService localService,
    required CurrentSession authService,
  }) : _clock = clock ?? DateTime.now,
       _remoteDataSource = remoteDataSource,
       _localService = localService,
       _authService = authService;

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
        if (pet != null && pet.ownerId == user.uid) return pet;
      }
    } catch (e) {
      debugPrint('雲端 getPet 失敗: $e');
    }
    return await _localService.getPet(user.uid, petId);
  }

  @override
  Future<PetWriteResult> createPet(PetModel pet) async {
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

    if (const StoragePolicy().usesCloud(user.membershipType)) {
      try {
        await _remoteDataSource.setPet(petId, petWithId);
        await _localService.clearPendingOperation(user.uid, petId);
      } catch (e) {
        if (!_isRetryable(e)) rethrow;
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
  Future<PetWriteResult> updatePet(String petId, PetModel pet) async {
    final user = await _authService.getUserData();
    if (user == null) throw PetWriteFailure('Authentication required.');
    if (pet.ownerId != user.uid) {
      throw PetWriteFailure('Pet owner does not match the active user.');
    }
    final cachedPet = await _localService.getPet(user.uid, petId);
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
              await _localService.updatePet(user.uid, petId, remotePet);
              return PetWriteResult.conflict;
            }
          }
        }
        await _remoteDataSource.updatePet(petId, versionedPet);
        await _localService.clearPendingOperation(user.uid, petId);
      } catch (e) {
        if (!_isRetryable(e)) rethrow;
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
  Future<void> deletePet(String petId) async {
    final user = await _authService.getUserData();
    if (user == null) throw PetWriteFailure('Authentication required.');

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
