import 'package:ai_pet_communication/features/home/presentation/home_screen.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/models/user_model.dart';
import 'package:ai_pet_communication/features/auth/application/auth_service.dart';
import 'package:ai_pet_communication/features/pet/application/pet_service.dart';
import 'package:ai_pet_communication/services/ad_service.dart';
import 'package:ai_pet_communication/app/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_pet_communication/services/membership_action_handler.dart';
import 'package:mocktail/mocktail.dart';

class MockPetService extends Mock implements PetService {}

class MockAuthService extends Mock implements AuthService {}

class MockAdService extends Mock implements AdService {}

class MockMembershipActionHandler extends Mock
    implements MembershipActionHandler {}

void main() {
  late UserModel userModel;
  late MockPetService mockPetService;
  late MockAuthService mockAuthService;
  late MockAdService mockAdService;
  late MockMembershipActionHandler mockMembershipHandler;

  setUp(() {
    getIt.reset();
    getIt.allowReassignment = true;

    userModel = UserModel(
      uid: 'user123',
      email: 'test@example.com',
      displayName: 'Tester',
      points: 10,
      membershipTier: 'pro',
    );

    mockPetService = MockPetService();
    mockAuthService = MockAuthService();
    mockAdService = MockAdService();
    mockMembershipHandler = MockMembershipActionHandler();

    // Mock PetService ValueNotifiers
    when(
      () => mockPetService.isCloudActive,
    ).thenReturn(ValueNotifier<bool>(true));
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
        ),
      ]),
    );

    // Mock auth stream for sync indicator
    when(
      () => mockAuthService.getUserStream(),
    ).thenAnswer((_) => Stream.value(userModel));

    // Register mocks in getIt
    getIt.registerSingleton<PetService>(mockPetService);
    getIt.registerSingleton<AuthService>(mockAuthService);
    getIt.registerSingleton<AdService>(mockAdService);
    getIt.registerSingleton<MembershipActionHandler>(mockMembershipHandler);
  });

  tearDown(() {
    getIt.reset();
  });

  testWidgets('HomeScreen shows pet list and sync indicator', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: HomeScreen(
          user: userModel,
          authService: mockAuthService,
          petService: mockPetService,
          adService: mockAdService,
          membershipHandler: mockMembershipHandler,
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
