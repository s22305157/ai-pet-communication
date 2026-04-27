import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pet_model.dart';

class PetService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<PetModel>> watchPetsByOwner(String uid) {
    return _db
        .collection('Pets')
        .where('owner_id', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => PetModel.fromDoc(doc)).toList();
    });
  }

  Future<String> createPet(PetModel pet) async {
    final ref = await _db.collection('Pets').add(pet.toMap());
    return ref.id;
  }

  Future<void> updatePet(String petId, PetModel pet) async {
    await _db.collection('Pets').doc(petId).update({
      'name': pet.name,
      'species': pet.species,
      'breed': pet.breed,
      'gender': pet.gender,
      'birthday': pet.birthday,
      'personality': pet.personality,
      'avatar_url': pet.avatarUrl,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePet(String petId) async {
    await _db.collection('Pets').doc(petId).delete();
  }
}
