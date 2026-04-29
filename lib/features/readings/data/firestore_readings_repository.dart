import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/reading.dart';
import 'readings_repository.dart';

class FirestoreReadingsRepository implements ReadingsRepository {
  final FirebaseFirestore _firestore;

  FirestoreReadingsRepository(this._firestore);

  @override
  Stream<List<Reading>> watchReadingsByPetId(String petId) {
    return _firestore
        .collection('pets')
        .doc(petId)
        .collection('readings')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Reading.fromMap(doc.data(), doc.id))
            .toList());
  }
  @override
  Future<Reading?> getReadingById(String petId, String readingId) async {
    final doc = await _firestore
        .collection('pets')
        .doc(petId)
        .collection('readings')
        .doc(readingId)
        .get();
        
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return Reading.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<void> addReading(Reading reading) async {
    final docRef = reading.id.isEmpty
        ? _firestore.collection('pets').doc(reading.petId).collection('readings').doc()
        : _firestore.collection('pets').doc(reading.petId).collection('readings').doc(reading.id);
        
    await docRef.set(reading.toMap());
  }

  @override
  Future<void> deleteReading(String petId, String readingId) async {
    await _firestore
        .collection('pets')
        .doc(petId)
        .collection('readings')
        .doc(readingId)
        .delete();
  }
}
