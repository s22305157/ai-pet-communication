import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:ai_pet_communicator/features/readings/domain/reading.dart';
import 'package:ai_pet_communicator/features/readings/data/firestore_readings_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreReadingsRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FirestoreReadingsRepository(firestore);
  });

  test('addReading adds a reading to the pet subcollection', () async {
    final reading = Reading(
      id: 'r1',
      petId: 'p1',
      title: 'Title',
      content: 'Content',
      createdAt: DateTime.now(),
    );

    await repository.addReading(reading);

    final snapshot = await firestore
        .collection('pets')
        .doc('p1')
        .collection('readings')
        .doc('r1')
        .get();

    expect(snapshot.exists, true);
    expect(snapshot.data()?['title'], 'Title');
  });

  test('watchReadingsByPetId returns readings ordered by createdAt desc', () async {
    final date1 = DateTime(2026, 4, 1);
    final date2 = DateTime(2026, 4, 2);

    await firestore.collection('pets').doc('p1').collection('readings').doc('r1').set({
      'petId': 'p1',
      'title': 'Reading 1',
      'content': 'Content 1',
      'createdAt': date1.toIso8601String(),
    });

    await firestore.collection('pets').doc('p1').collection('readings').doc('r2').set({
      'petId': 'p1',
      'title': 'Reading 2',
      'content': 'Content 2',
      'createdAt': date2.toIso8601String(),
    });

    final stream = repository.watchReadingsByPetId('p1');
    final readingsList = await stream.first;

    expect(readingsList.length, 2);
    // ordered by createdAt desc, so r2 (date2) should be first
    expect(readingsList.first.id, 'r2');
    expect(readingsList.last.id, 'r1');
  });

  test('deleteReading removes the reading from the pet subcollection', () async {
    await firestore.collection('pets').doc('p1').collection('readings').doc('r1').set({
      'title': 'Title',
    });

    await repository.deleteReading('p1', 'r1');

    final snapshot = await firestore
        .collection('pets')
        .doc('p1')
        .collection('readings')
        .doc('r1')
        .get();

    expect(snapshot.exists, false);
  });
}
