import '../models/pet_model.dart';

abstract class PetRepository {
  Future<PetModel?> getPet(String petId);
  Future<void> createPet(PetModel pet);
  Future<void> updatePet(String petId, PetModel pet);
  Future<void> deletePet(String petId);
  Future<bool> shouldUseCloud();
}
