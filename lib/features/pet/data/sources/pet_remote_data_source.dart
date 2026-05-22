import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../domain/models/pet_model.dart';

class PetRemoteDataSource {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  FirebaseFirestore get db => _db;

  PetRemoteDataSource({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  Future<PetModel?> getPet(String petId) async {
    final doc = await _db.collection('pets').doc(petId).get();
    return doc.exists ? PetModel.fromDoc(doc) : null;
  }

  Future<void> setPet(String petId, PetModel pet) async {
    await _db.collection('pets').doc(petId).set(pet.toMap());
  }

  Future<void> updatePet(String petId, PetModel pet) async {
    await _db.collection('pets').doc(petId).update(pet.toMap());
  }

  Future<void> deletePet(String petId) async {
    await _db.collection('pets').doc(petId).delete();
  }

  Stream<List<PetModel>> watchPetsByOwner(String uid) {
    return _db
        .collection('pets')
        .where('owner_id', isEqualTo: uid)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => PetModel.fromDoc(doc)).toList());
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
