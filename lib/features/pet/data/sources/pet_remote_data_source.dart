import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../domain/models/pet_model.dart';

class PetRemoteDataSource {
  static const int maxAvatarSizeBytes = 10 * 1024 * 1024;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final FirebaseFunctions? _customFunctions;
  FirebaseFunctions get _functions =>
      _customFunctions ?? FirebaseFunctions.instance;

  FirebaseFirestore get db => _db;

  PetRemoteDataSource({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _customFunctions = functions;

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

  Future<void> deletePet(String petId, {String? avatarUrl}) async {
    await _functions.httpsCallable('deletePetData').call(<String, dynamic>{
      'petId': petId,
      'avatarUrl': avatarUrl,
    });
  }

  Future<DateTime?> getPetDeletionTime(String petId) async {
    final doc = await _db.collection('petTombstones').doc(petId).get();
    if (!doc.exists) return null;
    final value = doc.data()?['deleted_at'];
    return value is Timestamp ? value.toDate() : null;
  }

  Stream<List<PetModel>> watchPetsByOwner(String uid) {
    return _db
        .collection('pets')
        .where('owner_id', isEqualTo: uid)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => PetModel.fromDoc(doc)).toList(),
        );
  }

  Future<String> uploadPetAvatar(
    String uid,
    String imageId,
    Uint8List imageBytes,
  ) async {
    if (imageBytes.lengthInBytes > maxAvatarSizeBytes) {
      throw ArgumentError('Pet avatar must not exceed 10 MiB.');
    }

    final format = _detectImageFormat(imageBytes);
    final ref = _storage
        .ref()
        .child('pets')
        .child(uid)
        .child('$imageId.${format.extension}');
    final uploadTask = ref.putData(
      imageBytes,
      SettableMetadata(contentType: format.contentType),
    );
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  _PetAvatarImageFormat _detectImageFormat(Uint8List bytes) {
    if (bytes.lengthInBytes >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return const _PetAvatarImageFormat('jpg', 'image/jpeg');
    }

    if (bytes.lengthInBytes >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a) {
      return const _PetAvatarImageFormat('png', 'image/png');
    }

    throw ArgumentError('Pet avatar must be a JPEG or PNG image.');
  }
}

class _PetAvatarImageFormat {
  final String extension;
  final String contentType;

  const _PetAvatarImageFormat(this.extension, this.contentType);
}
