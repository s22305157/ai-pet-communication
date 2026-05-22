import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/features/pet/presentation/pet_detail_screen.dart';
import 'package:ai_pet_communication/features/pet/presentation/widgets/reading_list_tile.dart';
import 'package:ai_pet_communication/features/pet/application/pet_service.dart';
import 'package:ai_pet_communication/services/auth_service.dart';
import 'package:ai_pet_communication/services/ad_service.dart';
import 'package:ai_pet_communication/features/readings/data/readings_repository.dart';
import 'package:ai_pet_communication/features/readings/data/firestore_readings_repository.dart';
import 'package:ai_pet_communication/features/readings/application/reading_service.dart';

class MockPetService extends Mock implements PetService {}
class MockAuthService extends Mock implements AuthService {}
class MockAdService extends Mock implements AdService {}
class MockReadingService extends Mock implements ReadingService {}

void main() {
  late FakeFirebaseFirestore firestore;
  late ReadingsRepository readingsRepository;
  late ReadingService readingService;
  late MockPetService mockPetService;
  late MockAuthService mockAuthService;
  late MockAdService mockAdService;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    readingsRepository = FirestoreReadingsRepository(firestore);
    readingService = ReadingService(readingsRepository);

    mockPetService = MockPetService();
    when(() => mockPetService.isCloudActive).thenReturn(ValueNotifier<bool>(true));

    mockAuthService = MockAuthService();
    mockAdService = MockAdService();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: NoSplash.splashFactory,
      ),
      home: PetDetailScreen(
        pet: PetModel(
          petId: 'pet_1',
          ownerId: 'user_1',
          name: 'Fluffy',
          species: 'Cat',
          breed: 'Persian',
          gender: 'Female',
          birthday: '2020-01-01',
          personality: 'Lazy',
          avatarUrl: '',
        ),
        petService: mockPetService,
        readingsRepository: readingsRepository,
        authService: mockAuthService,
        adService: mockAdService,
        readingService: readingService,
      ),
    );
  }

  testWidgets('Displays Empty State when no readings are found', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle(); // wait for stream builder

    expect(find.text('尚無溝通紀錄'), findsOneWidget);
    expect(find.text('未來會在這裡顯示您與 Fluffy 的對話'), findsOneWidget);
  });

  testWidgets('Displays ReadingListTile when readings exist', (WidgetTester tester) async {
    // Populate fake firestore
    await firestore.collection('pets').doc('pet_1').collection('readings').doc('r1').set({
      'petId': 'pet_1',
      'title': 'Test AI Reading',
      'content': 'Your pet is happy!',
      'createdAt': DateTime.now().toIso8601String(),
    });

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.byType(ReadingListTile), findsOneWidget);
    expect(find.text('Test AI Reading'), findsOneWidget);
    expect(find.text('Your pet is happy!'), findsOneWidget);
  });

  testWidgets('Navigates to ReadingDetailScreen when ReadingListTile is tapped', (WidgetTester tester) async {
    await firestore.collection('pets').doc('pet_1').collection('readings').doc('r1').set({
      'petId': 'pet_1',
      'title': 'Test AI Reading',
      'content': 'Your pet is happy!',
      'createdAt': DateTime.now().toIso8601String(),
    });

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final tileFinder = find.byType(ReadingListTile);
    await tester.ensureVisible(tileFinder);
    await tester.pumpAndSettle();

    await tester.tap(tileFinder);
    await tester.pumpAndSettle();

    // Check if navigated to new screen
    expect(find.text('紀錄詳情'), findsOneWidget);
    expect(find.text('Test AI Reading'), findsOneWidget);
  });
}
