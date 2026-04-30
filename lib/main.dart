import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'constants.dart';
import 'services/subscription_service.dart';
import 'services/ad_service.dart';
import 'services/onboarding_service.dart';
import 'screens/onboarding/onboarding_screen.dart';

// 導入產生的 Firebase 設定選項
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化 Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 初始化 Hive 用於本地存儲
  await Hive.initFlutter();
  await Hive.openBox('local_pets');

  // 初始化訂閱服務 (RevenueCat)
  await SubscriptionService().initialize();

  // 初始化廣告服務 (AdMob)
  await AdService().initialize();
  
  runApp(const AiPetApp());
}

class AiPetApp extends StatelessWidget {
  const AiPetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PAWLINK',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          background: AppColors.background,
          surface: AppColors.surface,
        ),
        textTheme: GoogleFonts.outfitTextTheme(),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: OnboardingService().hasCompletedOnboarding(),
      builder: (context, onboardingSnap) {
        // 等待新手引導狀態載入
        if (onboardingSnap.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        // 如果尚未完成新手引導，導向引導頁面
        if (onboardingSnap.data == false) {
          return const OnboardingScreen();
        }

        // 已完成引導，檢查登入狀態
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnap) {
            if (authSnap.connectionState == ConnectionState.waiting) {
              return _buildLoadingScreen();
            }
            
            if (authSnap.hasData) {
              return HomeScreen(user: authSnap.data!);
            }
            
            return const LoginScreen();
          },
        );
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
