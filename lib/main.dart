import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ai_pet_communication/firebase_options.dart';
import 'package:ai_pet_communication/features/auth/application/auth_service.dart';
import 'package:ai_pet_communication/services/subscription_service.dart';
import 'package:ai_pet_communication/services/ad_service.dart';
import 'package:ai_pet_communication/features/auth/presentation/login_screen.dart';
import 'package:ai_pet_communication/features/home/presentation/home_screen.dart';
import 'package:ai_pet_communication/features/onboarding/presentation/onboarding_screen.dart';
import 'package:ai_pet_communication/models/user_model.dart';
import 'package:ai_pet_communication/app/injection.dart';

void main() async {
  debugPrint('DEBUG: >>> PAWLINK Final Startup Initiated <<<');

  try {
    WidgetsFlutterBinding.ensureInitialized();
    setupDependencies();
    debugPrint('DEBUG: [1] WidgetsBinding Initialized');

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('DEBUG: [2] Firebase initialized');

    await Hive.initFlutter();
    await Hive.openBox('local_pets');
    await Hive.openBox<dynamic>('local_readings');
    debugPrint('DEBUG: [3] Hive initialized');

    try {
      await getIt<SubscriptionService>().initialize();
      debugPrint('DEBUG: [4a] Subscription Service initialized');
    } catch (e) {
      debugPrint('DEBUG: [!] Subscription Error: $e');
    }

    try {
      await getIt<AdService>().initialize();
      debugPrint('DEBUG: [4b] Ad Service initialized');
    } catch (e) {
      debugPrint('DEBUG: [!] Ad Error: $e');
    }

    debugPrint('DEBUG: [5] Launching MyApp');
    runApp(const MyApp());
  } catch (e) {
    debugPrint('CRITICAL STARTUP ERROR: $e');
    runApp(
      MaterialApp(
        home: Scaffold(body: Center(child: Text('啟動失敗: $e'))),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: getIt<AuthService>().getUserStream(),
      builder: (context, session) => MaterialApp(
        key: ValueKey(session.data?.uid),
        title: 'PAWLINK 毛孩心語',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF914D)),
          useMaterial3: true,
          fontFamily: 'NotoSansTC',
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = getIt<AuthService>();

    return StreamBuilder<UserModel?>(
      stream: authService.getUserStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('無法讀取帳號資料，請重新登入或稍後重試。')),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFF914D)),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginScreen();
        }

        if (!user.hasCompletedOnboarding) {
          return const OnboardingScreen();
        }

        return HomeScreen(key: ValueKey(user.uid), user: user);
      },
    );
  }
}
