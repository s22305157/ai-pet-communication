import 'package:cloud_firestore/cloud_firestore.dart';

class PetModel {
  final String? petId;
  final String ownerId;
  final String name;
  final String species;
  final String breed;
  final String gender;
  final String birthday;
  final String personality;
  final String avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PetModel({
    this.petId,
    required this.ownerId,
    required this.name,
    required this.species,
    required this.breed,
    required this.gender,
    required this.birthday,
    required this.personality,
    required this.avatarUrl,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'owner_id': ownerId,
      'name': name,
      'species': species,
      'breed': breed,
      'gender': gender,
      'birthday': birthday,
      'personality': personality,
      'avatar_url': avatarUrl,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  factory PetModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return PetModel(
      petId: doc.id,
      ownerId: data['owner_id'] ?? '',
      name: data['name'] ?? '',
      species: data['species'] ?? '',
      breed: data['breed'] ?? '',
      gender: data['gender'] ?? '',
      birthday: data['birthday'] ?? '',
      personality: data['personality'] ?? '',
      avatarUrl: data['avatar_url'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
    );
  }

  PetModel copyWith({
    String? petId,
    String? ownerId,
    String? name,
    String? species,
    String? breed,
    String? gender,
    String? birthday,
    String? personality,
    String? avatarUrl,
  }) {
    return PetModel(
      petId: petId ?? this.petId,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      personality: personality ?? this.personality,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
