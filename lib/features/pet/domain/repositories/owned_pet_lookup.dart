import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';

abstract interface class OwnedPetLookup {
  Future<PetModel?> getPet(String uid, String petId);
}
