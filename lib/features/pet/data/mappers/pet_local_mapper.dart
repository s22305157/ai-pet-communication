import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';

class PetLocalMapper {
  static Map<String, dynamic> fields(PetModel pet) {
    return {
      'pet_id': pet.petId,
      'owner_id': pet.ownerId,
      'name': pet.name,
      'species': pet.species,
      'breed': pet.breed,
      'gender': pet.gender,
      'birthday': pet.birthday,
      'personality': pet.personality,
      'avatar_url': pet.avatarUrl,
      'color': pet.color,
      'weight': pet.weight,
    };
  }

  static Map<String, dynamic> toMap(PetModel pet) => {
    ...fields(pet),
    'created_at': pet.createdAt?.toIso8601String(),
    'updated_at': pet.updatedAt?.toIso8601String(),
  };
  static PetModel fromMap(Map<String, dynamic> data, {String? id}) {
    DateTime? parseDate(dynamic date) {
      if (date == null) return null;
      if (date is String) return DateTime.tryParse(date);
      return null;
    }

    return PetModel(
      petId: id ?? data['pet_id'] ?? '',
      ownerId: data['owner_id'] ?? '',
      name: data['name'] ?? '',
      species: data['species'] ?? '',
      breed: data['breed'] ?? '',
      gender: data['gender'] ?? '',
      birthday: data['birthday'] ?? '',
      personality: data['personality'] ?? '',
      avatarUrl: data['avatar_url'] ?? '',
      color: data['color'] ?? '',
      weight: (data['weight'] ?? 0.0).toDouble(),
      createdAt: parseDate(data['created_at']),
      updatedAt: parseDate(data['updated_at']),
    );
  }
}
