abstract interface class AccountCleanup {
  Future<void> clearUser(String uid);
}

abstract interface class PetReadingsCleanup {
  Future<void> clearPet(String uid, String petId);
}
