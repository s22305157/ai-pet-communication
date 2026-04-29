import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pet_model.dart';
import 'local_pet_service.dart';
import 'auth_service.dart';
import '../models/user_model.dart';

class PetService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final LocalPetService _localService = LocalPetService();
  final AuthService _authService = AuthService();

  // 判斷是否應使用雲端儲存 (Pro 以上版本)
  Future<bool> _shouldUseCloud() async {
    final userModel = await _authService.getUserData();
    return userModel?.membershipType != 'free';
  }

  // 根據 UID 監聽寵物列表 (自動切換本地/雲端)
  Stream<List<PetModel>> watchPetsByOwner(String uid) {
    // 這裡我們透過 StreamBuilder 的巢狀組合或外部傳入來決定更好
    // 但為了簡化，我們同時監聽 UserModel 的狀態
    return _authService.getUserStream().asyncExpand((user) {
      if (user == null || user.membershipType == 'free') {
        // Free 用戶：顯示本地資料
        return _localService.watchPets();
      } else {
        // Pro 用戶：顯示雲端資料
        return _db
            .collection('pets')
            .where('owner_id', isEqualTo: uid)
            .snapshots()
            .map((snapshot) {
          return snapshot.docs.map((doc) => PetModel.fromDoc(doc)).toList();
        });
      }
    });
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
