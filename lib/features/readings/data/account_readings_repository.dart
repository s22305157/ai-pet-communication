import '../../../services/auth_service.dart';
import '../../pet/data/local_pet_service.dart';
import '../domain/reading.dart';
import 'firestore_readings_repository.dart';
import 'local_readings_repository.dart';
import 'readings_repository.dart';

class AccountReadingsRepository implements ReadingsRepository {
  final AuthService _authService;
  final LocalPetService _localPets;
  final LocalReadingsRepository _localReadings;
  final FirestoreReadingsRepository _cloudReadings;

  AccountReadingsRepository({
    required AuthService authService,
    required LocalPetService localPets,
    required LocalReadingsRepository localReadings,
    required FirestoreReadingsRepository cloudReadings,
  }) : _authService = authService,
       _localPets = localPets,
       _localReadings = localReadings,
       _cloudReadings = cloudReadings;

  Future<({String uid, bool useLocal})> _scope(String petId) async {
    final user = await _authService.getUserData();
    if (user == null) throw StateError('Authentication required.');
    if (user.membershipType == 'free') {
      final pet = await _localPets.getPet(user.uid, petId);
      if (pet == null || pet.ownerId != user.uid) {
        throw StateError('Local pet does not belong to the active user.');
      }
      return (uid: user.uid, useLocal: true);
    }
    return (uid: user.uid, useLocal: false);
  }

  @override
  Stream<List<Reading>> watchReadingsByPetId(String petId) async* {
    final scope = await _scope(petId);
    if (scope.useLocal) {
      yield* _localReadings.watchReadings(scope.uid, petId);
    } else {
      yield* _cloudReadings.watchReadingsByPetId(petId);
    }
  }

  @override
  Future<Reading?> getReadingById(String petId, String readingId) async {
    final scope = await _scope(petId);
    return scope.useLocal
        ? _localReadings.getReading(scope.uid, petId, readingId)
        : _cloudReadings.getReadingById(petId, readingId);
  }

  @override
  Future<void> addReading(Reading reading) async {
    final scope = await _scope(reading.petId);
    if (scope.useLocal) {
      await _localReadings.addReading(scope.uid, reading);
    } else {
      await _cloudReadings.addReading(reading);
    }
  }

  @override
  Future<void> deleteReading(String petId, String readingId) async {
    final scope = await _scope(petId);
    if (scope.useLocal) {
      await _localReadings.deleteReading(scope.uid, petId, readingId);
    } else {
      await _cloudReadings.deleteReading(petId, readingId);
    }
  }
}
