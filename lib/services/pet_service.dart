import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/pet_model.dart';

class PetService {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  PetService({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  Stream<List<PetModel>> watchPetsByOwner(String uid) {
    return _db
        .collection('pets')
        .where('owner_id', isEqualTo: uid)
        // .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => PetModel.fromDoc(doc)).toList();
    });
  }

  Future<String> createPet(PetModel pet) async {
    final ref = await _db.collection('pets').add(pet.toMap());
    return ref.id;
  }

  Future<void> updatePet(String petId, PetModel pet) async {
    await _db.collection('pets').doc(petId).update(pet.toMap());
  }

  Future<void> deletePet(String petId) async {
    await _db.collection('pets').doc(petId).delete();
  }

  Future<String> uploadPetAvatar(String uid, String imageId, Uint8List imageBytes) async {
    final ref = _storage.ref().child('pets').child(uid).child('$imageId.jpg');
    final uploadTask = ref.putData(
      imageBytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }
}
