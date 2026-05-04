import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/subscription_service.dart';
import 'services/ad_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'models/user_model.dart';

void main() async {
  print('DEBUG: >>> PAWLINK Final Startup Initiated <<<');
  
  try {
    WidgetsFlutterBinding.ensureInitialized();
    print('DEBUG: [1] WidgetsBinding Initialized');
    
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('DEBUG: [2] Firebase initialized');

    await Hive.initFlutter();
    await Hive.openBox('local_pets');
    print('DEBUG: [3] Hive initialized');

    try {
      await SubscriptionService().initialize();
      print('DEBUG: [4a] Subscription Service initialized');
    } catch (e) { print('DEBUG: [!] Subscription Error: $e'); }
    
    try {
      await AdService().initialize();
      print('DEBUG: [4b] Ad Service initialized');
    } catch (e) { print('DEBUG: [!] Ad Error: $e'); }

    print('DEBUG: [5] Launching MyApp');
    runApp(const MyApp());
  } catch (e, stack) {
    print('CRITICAL STARTUP ERROR: $e');
    runApp(MaterialApp(home: Scaffold(body: Center(child: Text('啟動失敗: $e')))));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PAWLINK 毛孩心語',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF914D)),
        useMaterial3: true,
        fontFamily: 'NotoSansTC', 
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<UserModel?>(
      stream: authService.getUserStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFFFF914D))),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginScreen();
        }

        if (!user.hasCompletedOnboarding) {
          return const OnboardingScreen();
        }

        return HomeScreen(user: user);
      },
    );
  }
}
