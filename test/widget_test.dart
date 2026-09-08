import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ai_pet_communication/main.dart';
import 'package:ai_pet_communication/features/auth/application/auth_service.dart';
import 'package:ai_pet_communication/app/injection.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockAuthService mockAuthService;

  setUp(() {
    getIt.reset();
    getIt.allowReassignment = true;
    setupDependencies();
    mockAuthService = MockAuthService();
    getIt.registerSingleton<AuthService>(mockAuthService);
  });

  tearDown(() {
    getIt.reset();
  });

  testWidgets('App smoke test - Shows login screen when user is not logged in', (
    WidgetTester tester,
  ) async {
    when(
      () => mockAuthService.getUserStream(),
    ).thenAnswer((_) => Stream.value(null));

    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // Verify that the login screen is displayed (e.g. searching for PAWLINK text)
    expect(find.text('PAWLINK'), findsOneWidget);
    expect(find.text('AI Pet Communicator'), findsOneWidget);
  });
}
