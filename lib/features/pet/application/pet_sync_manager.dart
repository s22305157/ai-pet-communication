import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/pet_model.dart';
import '../data/local_pet_service.dart';
import '../data/sources/pet_remote_data_source.dart';

class PetSyncManager {
  final FirebaseFirestore _db;
  final LocalPetService _localService;
  final PetRemoteDataSource _remoteDataSource;

  // 追蹤雲端連線狀態，供 UI 顯示
  final ValueNotifier<bool> isCloudActive = ValueNotifier<bool>(true);

  // 追蹤是否正在進行遷移同步
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);

  PetSyncManager({
    FirebaseFirestore? firestore,
    LocalPetService? localService,
    PetRemoteDataSource? remoteDataSource,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _localService = localService ?? LocalPetService(),
        _remoteDataSource = remoteDataSource ?? PetRemoteDataSource(firestore: firestore);

  // 內部遷移邏輯：將本地資料推送到雲端 (使用 petId 進行唯一性檢查)
  Future<void> migrateIfNeeded(String uid) async {
    if (isSyncing.value) return; // 避免重複觸發

    try {
      final localPets = _localService.getAllPets();
      if (localPets.isEmpty) return;

      isSyncing.value = true;
      debugPrint("檢測到本地寵物資料，開始按 petId 進行遷移...");
      for (var pet in localPets) {
        final docRef = _db.collection('pets').doc(pet.petId);
        final existing = await docRef.get();

        if (!existing.exists) {
          // 雲端無資料：直接同步
          await _remoteDataSource.setPet(pet.petId, pet);
        } else {
          // 雲端有資料：執行衝突解決策略 (Timestamp Wins)
          final cloudPet = PetModel.fromDoc(existing);
          if (resolveConflict(pet, cloudPet)) {
            await _remoteDataSource.updatePet(pet.petId, pet);
          }
        }
      }
      debugPrint("遷移完成。");
    } catch (e) {
      debugPrint("遷移失敗: $e");
    } finally {
      isSyncing.value = false;
    }
  }

  // 衝突解決策略 (Timestamp Wins)
  bool resolveConflict(PetModel localPet, PetModel cloudPet) {
    final localTime = localPet.updatedAt ?? DateTime(2000);
    final cloudTime = cloudPet.updatedAt ?? DateTime(2000);
    return localTime.isAfter(cloudTime);
  }
}
