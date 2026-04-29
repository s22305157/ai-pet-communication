import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pet_model.dart';
import 'local_pet_service.dart';
import 'auth_service.dart';
import '../models/user_model.dart';

class PetService {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final LocalPetService _localService;
  final AuthService _authService;

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

  // 根據 UID 監聽寵物列表 (自動切換本地/雲端 + 自動遷移)
  Stream<List<PetModel>> watchPetsByOwner(String uid) {
    return _authService.getUserStream().asyncExpand((user) async* {
      if (user == null) {
        // 登出狀態：回傳空列表並停止監聽
        yield [];
      } else if (user.membershipType == 'free') {
        // Free 用戶：顯示本地資料
        yield* _localService.watchPets();
      } else {
        // Pro 用戶：先檢查是否需要遷移，然後顯示雲端資料
        // 在背景執行遷移，不阻塞 UI
        _migrateIfNeeded(uid);
        
        yield* _db
            .collection('pets')
            .where('owner_id', isEqualTo: uid)
            .snapshots()
            .map((snapshot) {
          return snapshot.docs.map((doc) => PetModel.fromDoc(doc)).toList();
        });
      }
    });
  }

  // 內部遷移邏輯：將本地資料推送到雲端
  Future<void> _migrateIfNeeded(String uid) async {
    final localPets = _localService.getAllPets();
    if (localPets.isEmpty) return;

    print("Detecting local pets, starting migration with conflict resolution...");
    for (var pet in localPets) {
      // 根據名稱與擁有者尋找雲端現有資料
      final existing = await _db
          .collection('pets')
          .where('owner_id', isEqualTo: uid)
          .where('name', isEqualTo: pet.name)
          .get();

      if (existing.docs.isEmpty) {
        // 雲端無資料：直接新增
        await _db.collection('pets').add(pet.toMap());
      } else {
        // 雲端有資料：執行衝突解決策略 (Timestamp Wins)
        final cloudDoc = existing.docs.first;
        final cloudPet = PetModel.fromDoc(cloudDoc);

        final localTime = pet.updatedAt ?? DateTime(2000);
        final cloudTime = cloudPet.updatedAt ?? DateTime(2000);

        if (localTime.isAfter(cloudTime)) {
          // 本地較新：更新雲端
          print("Conflict detected for ${pet.name}: Local is newer. Updating cloud...");
          await _db.collection('pets').doc(cloudDoc.id).update(pet.toMap());
        } else {
          // 雲端較新：不動作，保持雲端為準
          print("Conflict detected for ${pet.name}: Cloud is newer or same. Keeping cloud version.");
        }
      }
    }
    print("Migration and conflict resolution complete.");
  }

  Future<void> createPet(PetModel pet) async {
    if (await _shouldUseCloud()) {
      await _db.collection('pets').add(pet.toMap());
    } else {
      await _localService.createPet(pet);
    }
  }

  Future<void> updatePet(String petId, PetModel pet) async {
    if (await _shouldUseCloud()) {
      await _db.collection('pets').doc(petId).update(pet.toMap());
    } else {
      await _localService.updatePet(petId, pet);
    }
  }

  Future<void> deletePet(String petId) async {
    // 嘗試在雲端刪除
    try {
      await _db.collection('pets').doc(petId).delete();
    } catch (_) {
      // 如果雲端找不到或失敗，嘗試在本地刪除
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
