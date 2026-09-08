import 'package:flutter/foundation.dart';
import '../../domain/models/pet_model.dart';
import '../../domain/repositories/pet_repository.dart';
import '../local_pet_service.dart';
import '../sources/pet_remote_data_source.dart';
import '../../../../services/auth_service.dart';
import '../../../readings/data/local_readings_repository.dart';

class PetRepositoryImpl implements PetRepository {
  final PetRemoteDataSource _remoteDataSource;
  final LocalPetService _localService;
  final AuthService _authService;
  final LocalReadingsRepository? _localReadings;

  PetRepositoryImpl({
    required PetRemoteDataSource remoteDataSource,
    required LocalPetService localService,
    required AuthService authService,
    LocalReadingsRepository? localReadings,
  }) : _remoteDataSource = remoteDataSource,
       _localService = localService,
       _authService = authService,
       _localReadings = localReadings;

  @override
  Future<bool> shouldUseCloud() async {
    final userModel = await _authService.getUserData();
    return userModel != null && userModel.membershipType != 'free';
  }

  @override
  Future<PetModel?> getPet(String petId) async {
    final user = await _authService.getUserData();
    if (user == null) return null;

    try {
      if (user.membershipType != 'free') {
        final pet = await _remoteDataSource.getPet(petId);
        if (pet != null && pet.ownerId == user.uid) return pet;
      }
    } catch (e) {
      debugPrint('雲端 getPet 失敗: $e');
    }
    return await _localService.getPet(user.uid, petId);
  }

  @override
  Future<void> createPet(PetModel pet) async {
    final user = await _authService.getUserData();
    if (user == null) throw StateError('Authentication required.');
    if (pet.ownerId != user.uid) {
      throw StateError('Pet owner does not match the active user.');
    }

    final dbInstance = _remoteDataSource.db;
    final petId = pet.petId.isEmpty
        ? dbInstance.collection('pets').doc().id
        : pet.petId;
    final now = DateTime.now();
    final petWithId = pet.copyWith(
      petId: petId,
      createdAt: pet.createdAt ?? now,
      updatedAt: pet.updatedAt ?? now,
    );

    if (user.membershipType != 'free') {
      try {
        await _remoteDataSource.setPet(petId, petWithId);
        await _localService.clearPendingOperation(user.uid, petId);
      } catch (e) {
        debugPrint('建立寵物雲端同步失敗，已加入待同步佇列: $e');
        await _localService.updatePet(user.uid, petId, petWithId);
        final stored = await _localService.getPet(user.uid, petId);
        if (stored != null) {
          await _localService.markPendingUpsert(user.uid, stored);
        }
        return;
      }
    }
    await _localService.updatePet(user.uid, petId, petWithId);
  }

  @override
  Future<void> updatePet(String petId, PetModel pet) async {
    final user = await _authService.getUserData();
    if (user == null) throw StateError('Authentication required.');
    if (pet.ownerId != user.uid) {
      throw StateError('Pet owner does not match the active user.');
    }
    final cachedPet = await _localService.getPet(user.uid, petId);
    final versionedPet = pet.copyWith(
      createdAt: pet.createdAt ?? cachedPet?.createdAt,
      updatedAt: DateTime.now(),
    );

    if (user.membershipType != 'free') {
      try {
        final remotePet = await _remoteDataSource.getPet(petId);
        if (remotePet != null) {
          if (remotePet.ownerId != user.uid) {
            throw StateError(
              'Remote pet owner does not match the active user.',
            );
          }
          if (remotePet.updatedAt != null && pet.updatedAt != null) {
            if (remotePet.updatedAt!.isAfter(pet.updatedAt!)) {
              debugPrint('衝突：雲端資料較新。改為將雲端資料同步至本地。');
              await _localService.updatePet(user.uid, petId, remotePet);
              return;
            }
          }
        }
        await _remoteDataSource.updatePet(petId, versionedPet);
        await _localService.clearPendingOperation(user.uid, petId);
      } catch (e) {
        debugPrint('更新寵物雲端同步失敗，已加入待同步佇列: $e');
        await _localService.updatePet(user.uid, petId, versionedPet);
        final stored = await _localService.getPet(user.uid, petId);
        if (stored != null) {
          await _localService.markPendingUpsert(user.uid, stored);
        }
        return;
      }
    }
    await _localService.updatePet(user.uid, petId, versionedPet);
  }

  @override
  Future<void> deletePet(String petId) async {
    final user = await _authService.getUserData();
    if (user == null) throw StateError('Authentication required.');

    final localPet = await _localService.getPet(user.uid, petId);
    await _localService.markPendingDelete(
      user.uid,
      petId,
      avatarUrl: localPet?.avatarUrl,
    );
    await _localReadings?.clearPet(user.uid, petId);

    try {
      await _remoteDataSource.deletePet(petId, avatarUrl: localPet?.avatarUrl);
      await _localService.clearPendingOperation(user.uid, petId);
    } catch (e) {
      debugPrint('刪除尚未同步，保留 tombstone 與待同步操作: $e');
    }
  }
}
