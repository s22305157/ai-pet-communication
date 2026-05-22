import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../domain/models/pet_model.dart';
import '../data/local_pet_service.dart';
import '../data/sources/pet_remote_data_source.dart';
import 'pet_sync_manager.dart';
import '../../../services/auth_service.dart';
import '../../../injection.dart';

class PetService {
  final PetRemoteDataSource _remoteDataSource;
  final PetSyncManager _syncManager;
  final LocalPetService _localService;
  final AuthService _authService;

  // 100% 向後相容的 ValueNotifier 暴露，橋接至 PetSyncManager
  ValueNotifier<bool> get isCloudActive => _syncManager.isCloudActive;
  ValueNotifier<bool> get isSyncing => _syncManager.isSyncing;

  PetService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    LocalPetService? localService,
    AuthService? authService,
    PetRemoteDataSource? remoteDataSource,
    PetSyncManager? syncManager,
  })  : _localService = localService ?? getIt<LocalPetService>(),
        _authService = authService ?? getIt<AuthService>(),
        _remoteDataSource = remoteDataSource ?? PetRemoteDataSource(
          firestore: firestore ?? (getIt.isRegistered<FirebaseFirestore>() ? getIt<FirebaseFirestore>() : null),
          storage: storage ?? (getIt.isRegistered<FirebaseStorage>() ? getIt<FirebaseStorage>() : null),
        ),
        _syncManager = syncManager ?? PetSyncManager(
          firestore: firestore ?? (getIt.isRegistered<FirebaseFirestore>() ? getIt<FirebaseFirestore>() : null),
          localService: localService ?? (getIt.isRegistered<LocalPetService>() ? getIt<LocalPetService>() : null),
          remoteDataSource: remoteDataSource ?? PetRemoteDataSource(
            firestore: firestore ?? (getIt.isRegistered<FirebaseFirestore>() ? getIt<FirebaseFirestore>() : null),
            storage: storage ?? (getIt.isRegistered<FirebaseStorage>() ? getIt<FirebaseStorage>() : null),
          ),
        );


  // 判斷是否應使用雲端儲存 (Pro 以上版本)
  Future<bool> _shouldUseCloud() async {
    final userModel = await _authService.getUserData();
    return userModel?.membershipType != 'free';
  }

  // 根據 UID 監聽寵物列表 (自動切換本地/雲端 + 自動遷移 + 錯誤降級)
  Stream<List<PetModel>> watchPetsByOwner(String uid) async* {
    final user = await _authService.getUserData();
    
    if (user == null) {
      yield [];
      return;
    }

    if (user.membershipType == 'free') {
      yield* _localService.watchPets();
    } else {
      // 付費帳戶 (Plus/Pro)：先嘗試雲端，失敗則降級本地
      _syncManager.migrateIfNeeded(uid);
      
      final controller = StreamController<List<PetModel>>();
      StreamSubscription? cloudSub;
      StreamSubscription? localSub;

      void startLocalFallback() {
        if (localSub != null) return;
        _syncManager.isCloudActive.value = false;
        localSub = _localService.watchPets().listen(
          (data) {
            if (!controller.isClosed) controller.add(data);
          },
          onError: (e) {
            if (!controller.isClosed) controller.addError(e);
          },
        );
      }

      controller.onListen = () {
        _syncManager.isCloudActive.value = true;
        cloudSub = _remoteDataSource.watchPetsByOwner(uid).listen(
          (snapshot) {
            _syncManager.isCloudActive.value = true;
            if (!controller.isClosed) {
              controller.add(snapshot);
            }
          },
          onError: (error) {
            debugPrint('雲端監聽錯誤: $error。啟動本地降級串流。');
            startLocalFallback();
          },
          cancelOnError: false,
        );
      };

      controller.onCancel = () {
        cloudSub?.cancel();
        localSub?.cancel();
        controller.close();
      };

      yield* controller.stream;
    }
  }

  // 獲取單一寵物資料
  Future<PetModel?> getPet(String petId) async {
    try {
      if (await _shouldUseCloud()) {
        final pet = await _remoteDataSource.getPet(petId);
        if (pet != null) return pet;
      }
    } catch (e) {
      debugPrint('雲端 getPet 失敗: $e');
    }
    // 降級處理或免費方案
    return await _localService.getPet(petId);
  }

  Future<void> createPet(PetModel pet) async {
    // 確保 ID 在建立時即存在 (使用傳入的/配置的 Firestore 實例生成 ID 以支援單元測試)
    final dbInstance = _remoteDataSource.db;
    final petId = pet.petId.isEmpty ? dbInstance.collection('pets').doc().id : pet.petId;
    final petWithId = pet.copyWith(petId: petId);

    try {
      if (await _shouldUseCloud()) {
        await _remoteDataSource.setPet(petId, petWithId);
      }
      // 無論雲端是否成功，都在本地保留一份作為快照/Fallback
      await _localService.updatePet(petId, petWithId);
    } catch (e) {
      debugPrint('建立寵物雲端同步失敗，僅儲存至本地: $e');
      await _localService.updatePet(petId, petWithId);
    }
  }

  Future<void> updatePet(String petId, PetModel pet) async {
    try {
      if (await _shouldUseCloud()) {
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

  Future<void> deletePet(String petId) async {
    try {
      // 雙向刪除
      if (await _shouldUseCloud()) {
        await _remoteDataSource.deletePet(petId);
      }
      await _localService.deletePet(petId);
    } catch (e) {
      debugPrint('刪除寵物錯誤: $e');
      // 即使雲端失敗，也確保本地刪除以維持 UI 一致性
      await _localService.deletePet(petId);
    }
  }

  Future<String> uploadPetAvatar(String uid, String imageId, Uint8List imageBytes) async {
    return await _remoteDataSource.uploadPetAvatar(uid, imageId, imageBytes);
  }
}
