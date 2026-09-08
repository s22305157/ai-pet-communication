import 'package:ai_pet_communication/features/pet/domain/models/pet_write_result.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/features/pet/domain/repositories/pet_repository.dart';
import 'package:ai_pet_communication/features/pet/domain/repositories/avatar_upload_repository.dart';
import 'package:ai_pet_communication/features/pet/application/pet_stream_watcher.dart';
import 'package:ai_pet_communication/features/pet/application/pet_sync_manager.dart';

class PetService {
  final PetRepository _repository;
  final AvatarUploadRepository _avatarUploadRepository;
  final PetStreamWatcher _streamWatcher;
  final PetSyncManager _syncManager;

  // UI observes synchronization state; only the manager may update it.
  ValueListenable<bool> get isCloudActive => _syncManager.isCloudActive;
  ValueListenable<bool> get isSyncing => _syncManager.isSyncing;

  PetService({
    required PetRepository repository,
    required AvatarUploadRepository avatarUploadRepository,
    required PetStreamWatcher streamWatcher,
    required PetSyncManager syncManager,
  }) : _repository = repository,
       _avatarUploadRepository = avatarUploadRepository,
       _streamWatcher = streamWatcher,
       _syncManager = syncManager;

  // 根據 UID 監聽寵物列表
  Stream<List<PetModel>> watchPetsByOwner(String uid) {
    return _streamWatcher.watchPetsByOwner(uid);
  }

  // 獲取單一寵物資料
  Future<PetModel?> getPet(String petId) {
    return _repository.getPet(petId);
  }

  // 建立寵物
  Future<PetWriteResult> createPet(PetModel pet) {
    return _repository.createPet(pet);
  }

  // 更新寵物資料
  Future<PetWriteResult> updatePet(String petId, PetModel pet) {
    return _repository.updatePet(petId, pet);
  }

  // 刪除寵物資料
  Future<PetWriteResult> deletePet(String petId, {String? expectedOwnerId}) {
    return _repository.deletePet(petId, expectedOwnerId: expectedOwnerId);
  }

  // 上傳寵物大頭貼
  Future<String> uploadPetAvatar(
    String uid,
    String imageId,
    Uint8List imageBytes,
  ) {
    return _avatarUploadRepository.uploadPetAvatar(uid, imageId, imageBytes);
  }
}
