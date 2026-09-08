class PetModel {
  final String petId;
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
    required this.petId,
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
    DateTime? createdAt,
    DateTime? updatedAt,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
