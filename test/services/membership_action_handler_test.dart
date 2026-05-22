// test/services/membership_action_handler_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_pet_communication/services/membership_action_handler.dart';
import 'package:ai_pet_communication/services/auth_service.dart';
import 'package:ai_pet_communication/services/ad_service.dart';
import 'package:ai_pet_communication/models/user_model.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';

class MockAuthService extends Mock implements AuthService {}
class MockAdService extends Mock implements AdService {}

void main() {
  late MockAuthService mockAuthService;
  late MockAdService mockAdService;
  late MembershipActionHandler handler;
  late PetModel pet;

  setUpAll(() {
    // Avoid GoogleFonts throwing network exceptions during testing
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    mockAuthService = MockAuthService();
    mockAdService = MockAdService();
    handler = MembershipActionHandler(mockAuthService, mockAdService);

    pet = PetModel(
      petId: 'pet123',
      ownerId: 'user123',
      name: 'Buddy',
      species: '狗',
      breed: '黃金獵犬',
      gender: '公',
      birthday: '2022-01-01',
      personality: '活潑',
      avatarUrl: '',
      color: '黃色',
      weight: 15.0,
    );
  });

  testWidgets('Pro 會員：直接准入，無任何彈窗', (WidgetTester tester) async {
    final proUser = UserModel(
      uid: 'user123',
      email: 'pro@example.com',
      displayName: 'Pro User',
      points: 0,
      membershipTier: 'pro',
    );

    when(() => mockAuthService.getUserData()).thenAnswer((_) async => proUser);

    bool allowedCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  await handler.handleStartCommunication(
                    context,
                    pet,
                    onAllowed: () => allowedCalled = true,
                  );
                },
                child: const Text('Start'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(allowedCalled, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Plus 會員：顯示升級 Pro 方案彈窗', (WidgetTester tester) async {
    final plusUser = UserModel(
      uid: 'user123',
      email: 'plus@example.com',
      displayName: 'Plus User',
      points: 0,
      membershipTier: 'plus',
    );

    when(() => mockAuthService.getUserData()).thenAnswer((_) async => plusUser);

    bool allowedCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  await handler.handleStartCommunication(
                    context,
                    pet,
                    onAllowed: () => allowedCalled = true,
                  );
                },
                child: const Text('Start'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(allowedCalled, isFalse);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('解鎖 Pro 方案'), findsOneWidget);
  });

  testWidgets('Free 會員且擁有足夠點數：觸開扣點確認彈窗，確認扣點後扣除 1 PT 並執行插頁廣告與准入', (WidgetTester tester) async {
    final freeUser = UserModel(
      uid: 'user123',
      email: 'free@example.com',
      displayName: 'Free User',
      points: 5,
      membershipTier: 'free',
    );

    when(() => mockAuthService.getUserData()).thenAnswer((_) async => freeUser);
    when(() => mockAuthService.consumePoints(1)).thenAnswer((_) async => freeUser.copyWith(points: 4));
    when(() => mockAdService.showInterstitialAd()).thenAnswer((_) async => {});

    bool allowedCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  await handler.handleStartCommunication(
                    context,
                    pet,
                    onAllowed: () => allowedCalled = true,
                  );
                },
                child: const Text('Start'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(allowedCalled, isFalse);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('開始溝通'), findsOneWidget);
    expect(find.text('本次與 Buddy 的溝通將消耗 1 PT 點數。\n升級會員可享優惠或無限次溝通！'), findsOneWidget);

    // 點擊確認扣點
    await tester.tap(find.text('確認扣點'));
    await tester.pumpAndSettle();

    // 驗證是否扣點與播放廣告
    verify(() => mockAuthService.consumePoints(1)).called(1);
    verify(() => mockAdService.showInterstitialAd()).called(1);
    expect(allowedCalled, isTrue);
  });

  testWidgets('Free 會員點數為 0：顯示升級 Plus 方案彈窗', (WidgetTester tester) async {
    final freeUser0 = UserModel(
      uid: 'user123',
      email: 'free@example.com',
      displayName: 'Free User 0',
      points: 0,
      membershipTier: 'free',
    );

    when(() => mockAuthService.getUserData()).thenAnswer((_) async => freeUser0);

    bool allowedCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  await handler.handleStartCommunication(
                    context,
                    pet,
                    onAllowed: () => allowedCalled = true,
                  );
                },
                child: const Text('Start'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(allowedCalled, isFalse);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('解鎖 Plus 方案'), findsOneWidget);
    expect(find.text('觀看影片領點數'), findsOneWidget);
  });
}
