import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:ai_pet_communication/injection.dart';

class MockPetService extends Mock implements PetService {}
class MockAuthService extends Mock implements AuthService {}
class MockAdService extends Mock implements AdService {}

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    getIt.reset();
    getIt.allowReassignment = true;

    firestore = FakeFirebaseFirestore();

    // Register our real firestore and repositories/services
    getIt.registerSingleton<FirebaseFirestore>(firestore);
    getIt.registerSingleton<ReadingsRepository>(FirestoreReadingsRepository(firestore));
    getIt.registerSingleton<ReadingService>(ReadingService(getIt<ReadingsRepository>()));

    // Register mock PetService
    final mockPetService = MockPetService();
    when(() => mockPetService.isCloudActive).thenReturn(ValueNotifier<bool>(true));
    getIt.registerSingleton<PetService>(mockPetService);

    // Register mock AuthService
    final mockAuthService = MockAuthService();
    getIt.registerSingleton<AuthService>(mockAuthService);

    // Register mock AdService
    final mockAdService = MockAdService();
    getIt.registerSingleton<AdService>(mockAdService);
  });

  tearDown(() {
    getIt.reset();
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
