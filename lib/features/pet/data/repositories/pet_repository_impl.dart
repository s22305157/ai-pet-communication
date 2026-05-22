import 'package:flutter/foundation.dart';
import '../../domain/models/pet_model.dart';
import '../../domain/repositories/pet_repository.dart';
import '../local_pet_service.dart';
import '../sources/pet_remote_data_source.dart';
import '../../../../services/auth_service.dart';

class PetRepositoryImpl implements PetRepository {
  final PetRemoteDataSource _remoteDataSource;
  final LocalPetService _localService;
  final AuthService _authService;

  PetRepositoryImpl({
    required PetRemoteDataSource remoteDataSource,
    required LocalPetService localService,
    required AuthService authService,
  })  : _remoteDataSource = remoteDataSource,
        _localService = localService,
        _authService = authService;

  @override
  Future<bool> shouldUseCloud() async {
    final userModel = await _authService.getUserData();
    return userModel?.membershipType != 'free';
  }

  @override
  Future<PetModel?> getPet(String petId) async {
    try {
      if (await shouldUseCloud()) {
        final pet = await _remoteDataSource.getPet(petId);
        if (pet != null) return pet;
      }
    } catch (e) {
      debugPrint('雲端 getPet 失敗: $e');
    }
    return await _localService.getPet(petId);
  }

  @override
  Future<void> createPet(PetModel pet) async {
    final dbInstance = _remoteDataSource.db;
    final petId = pet.petId.isEmpty ? dbInstance.collection('pets').doc().id : pet.petId;
    final petWithId = pet.copyWith(petId: petId);

    try {
      if (await shouldUseCloud()) {
        await _remoteDataSource.setPet(petId, petWithId);
      }
      await _localService.updatePet(petId, petWithId);
    } catch (e) {
      debugPrint('建立寵物雲端同步失敗，僅儲存至本地: $e');
      await _localService.updatePet(petId, petWithId);
    }
  }

  @override
  Future<void> updatePet(String petId, PetModel pet) async {
    try {
      if (await shouldUseCloud()) {
        final remotePet = await _remoteDataSource.getPet(petId);
        if (remotePet != null) {
          if (remotePet.updatedAt != null && pet.updatedAt != null) {
            if (remotePet.updatedAt!.isAfter(pet.updatedAt!)) {
              debugPrint('衝突：雲端資料較新。改為將雲端資料同步至本地。');
              await _localService.updatePet(petId, remotePet);
              return;
            }
          }
        }
        await _remoteDataSource.updatePet(petId, pet);
      }
      await _localService.updatePet(petId, pet);
    } catch (e) {
      debugPrint('更新寵物雲端同步失敗，僅儲存至本地: $e');
      await _localService.updatePet(petId, pet);
    }
  }

  @override
  Future<void> deletePet(String petId) async {
    try {
      if (await shouldUseCloud()) {
        await _remoteDataSource.deletePet(petId);
      }
      await _localService.deletePet(petId);
    } catch (e) {
      debugPrint('刪除寵物錯誤: $e');
      await _localService.deletePet(petId);
    }
  }
}
