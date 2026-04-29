import 'package:ai_pet_communicator/home_screen.dart';
import 'package:ai_pet_communicator/models/pet_model.dart';
import 'package:ai_pet_communicator/services/auth_service.dart';
import 'package:ai_pet_communicator/services/pet_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockUser extends Mock implements User {}
class MockPetService extends Mock implements PetService {}
class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockUser mockUser;
  late MockPetService mockPetService;
  late MockAuthService mockAuthService;

  setUp(() {
    mockUser = MockUser();
    mockPetService = MockPetService();
    mockAuthService = MockAuthService();

    when(() => mockUser.uid).thenReturn('user123');
    when(() => mockUser.displayName).thenReturn('Tester');
    
    // Mock PetService ValueNotifiers
    when(() => mockPetService.isCloudActive).thenReturn(ValueNotifier<bool>(true));
    when(() => mockPetService.isSyncing).thenReturn(ValueNotifier<bool>(false));
    
    // Mock pet list stream
    when(() => mockPetService.watchPetsByOwner(any())).thenAnswer(
      (_) => Stream.value([
        PetModel(
          petId: 'pet1',
          ownerId: 'user123',
          name: 'Buddy',
          species: 'Dog',
          breed: 'Golden',
          gender: '公',
          birthday: '2020-01-01',
          personality: 'Happy',
          avatarUrl: '',
          color: 'Yellow',
          weight: 10.0,
        )
      ]),
    );

    // Mock auth stream for sync indicator
    when(() => mockAuthService.getUserStream()).thenAnswer((_) => Stream.value(null));
  });

  testWidgets('HomeScreen shows pet list and sync indicator', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: HomeScreen(
          user: mockUser,
          petService: mockPetService,
          authService: mockAuthService,
        ),
      ),
    );

    // Wait for stream to emit
    await tester.pumpAndSettle();

    // Verify pet name is shown
    expect(find.text('Buddy'), findsOneWidget);
    
    // Verify sync indicator (it's a tooltip/icon, let's check for the storage icon)
    expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);
  });
}
