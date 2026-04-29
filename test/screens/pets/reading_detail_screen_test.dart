import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:ai_pet_communicator/features/readings/domain/reading.dart';
import 'package:ai_pet_communicator/screens/pets/reading_detail_screen.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  Widget createWidgetUnderTest({Reading? reading, String petId = 'p1', String readingId = 'r1'}) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: NoSplash.splashFactory,
      ),
      home: ReadingDetailScreen(
        reading: reading,
        petId: petId,
        readingId: readingId,
        firestore: firestore,
      ),
    );
  }

  testWidgets('Displays content when reading is provided directly', (WidgetTester tester) async {
    final reading = Reading(
      id: 'r1',
      petId: 'p1',
      title: 'Direct Reading',
      content: 'This is provided directly.',
      mood: 'Happy',
      createdAt: DateTime(2026, 4, 1),
    );

    await tester.pumpWidget(createWidgetUnderTest(reading: reading));
    await tester.pumpAndSettle();

    expect(find.text('Direct Reading'), findsOneWidget);
    expect(find.text('This is provided directly.'), findsOneWidget);
    expect(find.text('Happy'), findsOneWidget);
  });

  testWidgets('Fetches reading from firestore when only readingId is provided', (WidgetTester tester) async {
    await firestore.collection('pets').doc('p1').collection('readings').doc('r1').set({
      'petId': 'p1',
      'title': 'Fetched Reading',
      'content': 'This was fetched from DB.',
      'createdAt': DateTime(2026, 4, 1).toIso8601String(),
    });

    // Provide no reading object, only IDs
    await tester.pumpWidget(createWidgetUnderTest(reading: null));
    
    // initially shows loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Fetched Reading'), findsOneWidget);
    expect(find.text('This was fetched from DB.'), findsOneWidget);
  });

  testWidgets('Displays error when reading cannot be found', (WidgetTester tester) async {
    // DB is empty
    await tester.pumpWidget(createWidgetUnderTest(reading: null, readingId: 'non_existent'));
    await tester.pumpAndSettle();

    expect(find.text('無法讀取該則紀錄'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('重試'), findsOneWidget);
  });
}
