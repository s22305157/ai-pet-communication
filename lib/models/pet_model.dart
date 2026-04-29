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
  final String color;
  final double weight;
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
    this.color = '',
    this.weight = 0.0,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap({bool isLocal = false}) {
    final map = {
      'owner_id': ownerId,
      'name': name,
      'species': species,
      'breed': breed,
      'gender': gender,
      'birthday': birthday,
      'personality': personality,
      'avatar_url': avatarUrl,
      'color': color,
      'weight': weight,
    };
    
    if (isLocal) {
      map['updated_at'] = DateTime.now().toIso8601String();
      if (createdAt == null) {
        map['created_at'] = DateTime.now().toIso8601String();
      } else {
        map['created_at'] = createdAt!.toIso8601String();
      }
    } else {
      map['updated_at'] = FieldValue.serverTimestamp();
      if (createdAt == null) {
        map['created_at'] = FieldValue.serverTimestamp();
      }
    }
    
    return map;
  }

  factory PetModel.fromMap(Map<String, dynamic> data, {String? id}) {
    DateTime? parseDate(dynamic date) {
      if (date == null) return null;
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.tryParse(date);
      return null;
    }

    return PetModel(
      petId: id,
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

  factory PetModel.fromDoc(DocumentSnapshot doc) {
    return PetModel.fromMap(doc.data() as Map<String, dynamic>, id: doc.id);
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
    String? color,
    double? weight,
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
      color: color ?? this.color,
      weight: weight ?? this.weight,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
