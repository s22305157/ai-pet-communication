import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../domain/models/pet_model.dart';
import '../domain/repositories/pet_repository.dart';
import '../data/repositories/pet_repository_impl.dart';
import '../domain/repositories/avatar_upload_repository.dart';
import '../data/repositories/avatar_upload_repository_impl.dart';
import 'pet_stream_watcher.dart';
import '../data/local_pet_service.dart';
import '../data/sources/pet_remote_data_source.dart';
import '../../readings/data/local_readings_repository.dart';
import 'pet_sync_manager.dart';
import '../../../services/auth_service.dart';
import '../../../injection.dart';

class PetService {
  final PetRepository _repository;
  final AvatarUploadRepository _avatarUploadRepository;
  final PetStreamWatcher _streamWatcher;
  final PetSyncManager _syncManager;

  // 100% 向後相容的 ValueNotifier 暴露，橋接至 PetSyncManager
  ValueNotifier<bool> get isCloudActive => _syncManager.isCloudActive;
  ValueNotifier<bool> get isSyncing => _syncManager.isSyncing;

  factory PetService({
    PetRepository? repository,
    AvatarUploadRepository? avatarUploadRepository,
    PetStreamWatcher? streamWatcher,
    PetSyncManager? syncManager,
    // 以下為向後相容參數，若傳入則會自動在內部實作，確保現有 45 個測試案例與依賴注入零受損
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    LocalPetService? localService,
    AuthService? authService,
    PetRemoteDataSource? remoteDataSource,
    LocalReadingsRepository? localReadings,
  }) {
    final finalSyncManager =
        syncManager ??
        (getIt.isRegistered<PetSyncManager>()
            ? getIt<PetSyncManager>()
            : PetSyncManager(
                firestore: firestore,
                storage: storage,
                localService: localService,
                remoteDataSource: remoteDataSource,
              ));

    final finalRemoteDataSource =
        remoteDataSource ??
        (getIt.isRegistered<PetRemoteDataSource>()
            ? getIt<PetRemoteDataSource>()
            : PetRemoteDataSource(firestore: firestore, storage: storage));
    final finalLocalService =
        localService ??
        (getIt.isRegistered<LocalPetService>()
            ? getIt<LocalPetService>()
            : LocalPetService());
    final finalAuthService =
        authService ??
        (getIt.isRegistered<AuthService>()
            ? getIt<AuthService>()
            : AuthService());

    final finalRepository =
        repository ??
        PetRepositoryImpl(
          remoteDataSource: finalRemoteDataSource,
          localService: finalLocalService,
          authService: finalAuthService,
          localReadings:
              localReadings ??
              (getIt.isRegistered<LocalReadingsRepository>()
                  ? getIt<LocalReadingsRepository>()
                  : null),
        );

    final finalAvatarUploadRepository =
        avatarUploadRepository ??
        AvatarUploadRepositoryImpl(remoteDataSource: finalRemoteDataSource);

    final finalStreamWatcher =
        streamWatcher ??
        PetStreamWatcher(
          remoteDataSource: finalRemoteDataSource,
          localService: finalLocalService,
          authService: finalAuthService,
          syncManager: finalSyncManager,
        );

    return PetService._internal(
      repository: finalRepository,
      avatarUploadRepository: finalAvatarUploadRepository,
      streamWatcher: finalStreamWatcher,
      syncManager: finalSyncManager,
    );
  }

  PetService._internal({
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
  Future<void> createPet(PetModel pet) {
    return _repository.createPet(pet);
  }

  // 更新寵物資料
  Future<void> updatePet(String petId, PetModel pet) {
    return _repository.updatePet(petId, pet);
  }

  // 刪除寵物資料
  Future<void> deletePet(String petId) {
    return _repository.deletePet(petId);
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
