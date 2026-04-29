import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/pet_model.dart';
import 'local_pet_service.dart';
import 'auth_service.dart';
import '../models/user_model.dart';

class PetService {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final LocalPetService _localService;
  final AuthService _authService;
  
  // 追蹤雲端連線狀態，供 UI 顯示
  final ValueNotifier<bool> isCloudActive = ValueNotifier<bool>(true);
  
  // 追蹤是否正在進行遷移同步
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);

  PetService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    LocalPetService? localService,
    AuthService? authService,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _localService = localService ?? LocalPetService(),
        _authService = authService ?? AuthService();

  // 判斷是否應使用雲端儲存 (Pro 以上版本)
  Future<bool> _shouldUseCloud() async {
    final userModel = await _authService.getUserData();
    return userModel?.membershipType != 'free';
  }

  // 根據 UID 監聽寵物列表 (自動切換本地/雲端 + 自動遷移 + 錯誤降級)
  Stream<List<PetModel>> watchPetsByOwner(String uid) {
    return _authService.getUserStream().asyncExpand((user) async* {
      if (user == null) {
        yield [];
      } else if (user.membershipType == 'free') {
        yield* _localService.watchPets();
      } else {
        // 付費帳戶 (Plus/Pro)：先嘗試雲端，失敗則降級本地
        _migrateIfNeeded(uid);
        isCloudActive.value = true;
        
        final cloudStream = _db
            .collection('pets')
            .where('owner_id', isEqualTo: uid)
            .snapshots()
            .map((snapshot) {
          isCloudActive.value = true; // 成功收到快照，設為 true
          return snapshot.docs.map((doc) => PetModel.fromDoc(doc)).toList();
        });

        yield* cloudStream.handleError((error) {
          debugPrint('Cloud Watch Error: $error. Falling back to local.');
          isCloudActive.value = false; // 報錯，設為 false
          // 這裡可以發送全域提示，P2 後續會加入 UI 提示
        }).asBroadcastStream();
        
        // 額外確保：如果雲端流沒資料或報錯，至少還有本地可以看 (這裡邏輯稍後優化)
      }
    });
  }

  // 內部遷移邏輯：將本地資料推送到雲端 (使用 petId 進行唯一性檢查)
  Future<void> _migrateIfNeeded(String uid) async {
    if (isSyncing.value) return; // 避免重複觸發
    
    try {
      final localPets = _localService.getAllPets();
      if (localPets.isEmpty) return;

      isSyncing.value = true;
      debugPrint("Detecting local pets, starting migration by petId...");
      for (var pet in localPets) {
        final docRef = _db.collection('pets').doc(pet.petId);
        final existing = await docRef.get();

        if (!existing.exists) {
          // 雲端無資料：直接同步
          await docRef.set(pet.toMap());
        } else {
          // 雲端有資料：執行衝突解決策略 (Timestamp Wins)
          final cloudPet = PetModel.fromDoc(existing);
          final localTime = pet.updatedAt ?? DateTime(2000);
          final cloudTime = cloudPet.updatedAt ?? DateTime(2000);

          if (localTime.isAfter(cloudTime)) {
            await docRef.update(pet.toMap());
          }
        }
      }
      // 遷移完成後可以選擇清理本地，但為了保險我們暫時保留
      debugPrint("Migration complete.");
    } catch (e) {
      debugPrint("Migration failed: $e");
    } finally {
      isSyncing.value = false;
    }
  }

  Future<void> createPet(PetModel pet) async {
    // 確保 ID 在建立時即存在
    final petId = pet.petId.isEmpty ? _db.collection('pets').doc().id : pet.petId;
    final petWithId = pet.copyWith(petId: petId);

    try {
      if (await _shouldUseCloud()) {
        await _db.collection('pets').doc(petId).set(petWithId.toMap());
      }
      // 無論雲端是否成功，都在本地保留一份作為快照/Fallback
      await _localService.updatePet(petId, petWithId);
    } catch (e) {
      debugPrint('Create Pet Cloud Failure, saved to local only: $e');
      await _localService.updatePet(petId, petWithId);
      // 這裡後續會加入「待同步」標記
    }
  }

  Future<void> updatePet(String petId, PetModel pet) async {
    try {
      if (await _shouldUseCloud()) {
        final docRef = _db.collection('pets').doc(petId);
        
        final remoteDoc = await docRef.get();
        if (remoteDoc.exists) {
          final remotePet = PetModel.fromDoc(remoteDoc);
          if (remotePet.updatedAt != null && pet.updatedAt != null) {
            if (remotePet.updatedAt!.isAfter(pet.updatedAt!)) {
              debugPrint('Conflict: Cloud is newer. Syncing cloud to local instead.');
              await _localService.updatePet(petId, remotePet);
              return;
            }
          }
        }
        await docRef.update(pet.toMap());
      }
      await _localService.updatePet(petId, pet);
    } catch (e) {
      debugPrint('Update Pet Cloud Failure, saved to local only: $e');
      await _localService.updatePet(petId, pet);
    }
  }

  Future<void> deletePet(String petId) async {
    try {
      // 雙向刪除
      if (await _shouldUseCloud()) {
        await _db.collection('pets').doc(petId).delete();
      }
      await _localService.deletePet(petId);
    } catch (e) {
      debugPrint('Delete Pet Error: $e');
      // 即使雲端失敗，也確保本地刪除以維持 UI 一致性
      await _localService.deletePet(petId);
    }
  }

  Future<String> uploadPetAvatar(String uid, String imageId, Uint8List imageBytes) async {
    // 頭像上傳暫時統一使用雲端 Storage (或可實作本地路徑儲存)
    final ref = _storage.ref().child('pets').child(uid).child('$imageId.jpg');
    final uploadTask = ref.putData(
      imageBytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }
}
