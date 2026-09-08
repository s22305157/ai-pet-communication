import '../../../core/session/current_session.dart';
import '../../../core/storage/account_cleanup.dart';
import '../domain/models/pet_model.dart';
import '../domain/models/pet_write_result.dart';
import '../domain/repositories/pet_repository.dart';

/// Application-level coordination of pet deletion and local reading cleanup.
class PetCleanupRepository implements PetRepository {
  const PetCleanupRepository({
    required this.pets,
    required this.session,
    required this.readings,
  });
  final PetRepository pets;
  final CurrentSession session;
  final PetReadingsCleanup readings;

  @override
  Future<PetModel?> getPet(String petId) => pets.getPet(petId);
  @override
  Future<bool> shouldUseCloud() => pets.shouldUseCloud();
  @override
  Future<PetWriteResult> createPet(PetModel pet) => pets.createPet(pet);
  @override
  Future<PetWriteResult> updatePet(String petId, PetModel pet) =>
      pets.updatePet(petId, pet);
  @override
  Future<PetWriteResult> deletePet(
    String petId, {
    String? expectedOwnerId,
  }) async {
    final user = await session.getUserData();
    if (user == null) throw const PetWriteFailure('請先登入');
    if (expectedOwnerId != null && expectedOwnerId != user.uid) {
      throw const PetWriteFailure('帳號已變更');
    }
    final result = await pets.deletePet(petId, expectedOwnerId: user.uid);
    await readings.clearPet(user.uid, petId);
    return result;
  }
}
