import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/features/pet/data/mappers/pet_local_mapper.dart';

class PetFirestoreMapper {
  static Map<String, dynamic> create(PetModel pet) => {
    ...update(pet),
    'created_at': pet.createdAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(pet.createdAt!),
  };
  static Map<String, dynamic> update(PetModel pet) => {
    ...PetLocalMapper.fields(pet),
    'updated_at': FieldValue.serverTimestamp(),
  };
  static PetModel fromDoc(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map);
    for (final key in ['created_at', 'updated_at']) {
      if (data[key] is Timestamp) {
        data[key] = (data[key] as Timestamp).toDate().toIso8601String();
      }
    }
    return PetLocalMapper.fromMap(data, id: doc.id);
  }
}
