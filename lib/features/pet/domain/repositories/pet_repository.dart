import 'package:ai_pet_communication/features/pet/domain/models/pet_write_result.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';

abstract class PetRepository {
  Future<PetModel?> getPet(String petId);
  Future<PetWriteResult> createPet(PetModel pet);
  Future<PetWriteResult> updatePet(String petId, PetModel pet);
  Future<PetWriteResult> deletePet(String petId, {String? expectedOwnerId});
  Future<bool> shouldUseCloud();
}
