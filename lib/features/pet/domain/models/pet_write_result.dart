enum PetWriteResult { saved, pendingSync, conflict }

class PetVersionConflict implements Exception {
  const PetVersionConflict();
}

class PetWriteFailure implements Exception {
  final String message;
  const PetWriteFailure(this.message);
  @override
  String toString() => message;
}
