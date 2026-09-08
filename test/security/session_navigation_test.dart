import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rxdart/rxdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ai_pet_communication/main.dart';
import 'package:ai_pet_communication/app/injection.dart';
import 'package:ai_pet_communication/features/auth/application/auth_service.dart';
import 'package:ai_pet_communication/models/user_model.dart';

class Auth extends Mock implements AuthService {}

void main() {
  testWidgets(
    'sign-out removes pushed private routes, not only the home page',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      final users = BehaviorSubject<UserModel?>.seeded(
        UserModel(uid: 'a', email: '', displayName: 'A'),
      );
      final auth = Auth();
      when(() => auth.getUserStream()).thenAnswer((_) => users.stream);
      await getIt.reset();
      getIt.registerSingleton<AuthService>(auth);
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('A private page')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('A private page'), findsOneWidget);
      users.add(null);
      await tester.pumpAndSettle();
      expect(find.text('A private page'), findsNothing);
      expect(find.text('PAWLINK'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await users.close();
      await getIt.reset();
    },
  );
}
