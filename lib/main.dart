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
import 'services/auth_service.dart';
import 'models/user_model.dart';
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
  try {
    await SubscriptionService().initialize();
  } catch (e) {
    debugPrint('RevenueCat 初始化跳過: $e');
  }

  // 初始化廣告服務 (AdMob)
  try {
    await AdService().initialize();
  } catch (e) {
    debugPrint('AdMob 初始化跳過: $e');
  }
  
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
    final AuthService authService = AuthService();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        if (authSnap.hasData) {
          // 已登入，接著檢查帳號的新手導引狀態
          return StreamBuilder<UserModel?>(
            stream: authService.getUserStream(),
            builder: (context, userSnap) {
              if (userSnap.connectionState == ConnectionState.waiting) {
                return _buildLoadingScreen();
              }

              final userModel = userSnap.data;
              if (userModel == null) {
                // 如果抓不到 UserModel，可能是在建立中，顯示載入中
                return _buildLoadingScreen();
              }

              // 如果帳號尚未完成新手導引，顯示引導頁面
              if (!userModel.hasCompletedOnboarding) {
                return const OnboardingScreen();
              }

              // 已完成導引，顯示主畫面
              return HomeScreen(user: authSnap.data!);
            },
          );
        }

        // 未登入，直接顯示登入頁面
        return const LoginScreen();
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
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.pets_rounded,
                size: 80,
                color: AppColors.primary,
              ),
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
