import 'package:flutter_test/flutter_test.dart';
import 'package:ai_pet_communicator/features/readings/domain/reading.dart';

void main() {
  test('Reading model stores petId and createdAt', () {
    final reading = Reading(
      id: 'r1',
      petId: 'p1',
      title: 'Title',
      content: '您的寵物今天心情很好，想吃點零食。',
      createdAt: DateTime(2026, 4, 28),
    );

    expect(reading.petId, 'p1');
    expect(reading.content, '您的寵物今天心情很好，想吃點零食。');
  });

  test('toMap and fromMap work correctly', () {
    final originalDate = DateTime(2026, 4, 28);
    final reading = Reading(
      id: 'r1',
      petId: 'p1',
      title: 'Title',
      content: 'Content',
      mood: 'Happy',
      createdAt: originalDate,
    );

    final map = reading.toMap();
    final fromMap = Reading.fromMap(map, 'r1');

    expect(fromMap.id, 'r1');
    expect(fromMap.petId, 'p1');
    expect(fromMap.mood, 'Happy');
    expect(fromMap.createdAt, originalDate);
  });
}
