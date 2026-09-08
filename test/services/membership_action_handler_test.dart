import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ai_pet_communication/services/membership_action_handler.dart';
import 'package:ai_pet_communication/features/auth/application/auth_service.dart';
import 'package:ai_pet_communication/services/ad_service.dart';
import 'package:ai_pet_communication/services/credit_service.dart';
import 'package:ai_pet_communication/models/user_model.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';

class MockAuthService extends Mock implements AuthService {}

class MockAdService extends Mock implements AdService {}

class MockCreditService extends Mock implements CreditService {}

void main() {
  final pet = PetModel(
    petId: 'pet1',
    ownerId: 'user1',
    name: 'Buddy',
    species: '狗',
    breed: '',
    gender: '',
    birthday: '',
    personality: '',
    avatarUrl: '',
  );
  for (final tier in ['free', 'plus', 'pro']) {
    for (final points in [0, 5]) {
      testWidgets(
        '$tier with $points points starts without reservation or billing dialog',
        (tester) async {
          final auth = MockAuthService();
          final ads = MockAdService();
          final credits = MockCreditService();
          when(() => auth.getUserData()).thenAnswer(
            (_) async => UserModel(
              uid: 'user1',
              email: 'test@example.com',
              displayName: 'test',
              points: points,
              membershipTier: tier,
            ),
          );
          final handler = MembershipActionHandler(auth, ads, credits);
          var allowed = false;
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) => TextButton(
                  onPressed: () => handler.handleStartCommunication(
                    context,
                    pet,
                    onAllowed: (id) {
                      expect(id, isNull);
                      allowed = true;
                    },
                  ),
                  child: const Text('Start'),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Start'));
          await tester.pumpAndSettle();
          expect(allowed, isTrue);
          expect(find.byType(AlertDialog), findsNothing);
          verifyZeroInteractions(credits);
          verifyZeroInteractions(ads);
        },
      );
    }
  }
  testWidgets('logged-out users cannot enter', (tester) async {
    final auth = MockAuthService();
    final credits = MockCreditService();
    when(() => auth.getUserData()).thenAnswer((_) async => null);
    final handler = MembershipActionHandler(auth, MockAdService(), credits);
    var allowed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => handler.handleStartCommunication(
                context,
                pet,
                onAllowed: (_) => allowed = true,
              ),
              child: const Text('Start'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(allowed, isFalse);
    verifyZeroInteractions(credits);
  });
}
