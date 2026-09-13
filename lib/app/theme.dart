import 'package:flutter/material.dart';

class AppColors {
  // PAWLINK 淺色主題配色 (AI Pet Communicator)
  static const Color primary = Color(0xFF7BB3D1); // 標誌中的淺藍色
  static const Color secondary = Color(0xFF7EC8B7); // 標誌中的淺藍綠色
  static const Color accent = Color(0xFF2D4A5E); // 深石板藍（用於強調）

  static const Color background = Colors.white; // 純白背景
  static const Color surface = Colors.white; // 表面顏色
  static const Color surfaceSoft = Color(0xFFF0F7FA);
  static const Color surfaceMint = Color(0xFFEDF7F5);
  static const Color outline = Color(0xFFD4E3EA);

  static const Color textPrimary = Color(0xFF2D4A5E); // 主要文本色（深石板藍）
  static const Color textSecondary = Color(0xFF486779);
  static const Color error = Color(0xFFB3261E);

  // 背景漸層（符合品牌氛圍的微光漸層）
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF0F8FF), // 愛麗絲藍
      Color(0xFFE0F2F1), // 極淺藍綠色
    ],
  );
}

class AppTheme {
  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.accent,
          onPrimary: Colors.white,
          primaryContainer: AppColors.surfaceSoft,
          onPrimaryContainer: AppColors.textPrimary,
          secondary: AppColors.secondary,
          onSecondary: AppColors.textPrimary,
          secondaryContainer: AppColors.surfaceMint,
          onSecondaryContainer: AppColors.textPrimary,
          tertiary: AppColors.textSecondary,
          tertiaryContainer: AppColors.surfaceSoft,
          onTertiaryContainer: AppColors.textPrimary,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          onSurfaceVariant: AppColors.textSecondary,
          surfaceContainerLowest: AppColors.surface,
          surfaceContainerLow: AppColors.surfaceSoft,
          surfaceContainer: AppColors.surfaceSoft,
          surfaceContainerHigh: AppColors.surfaceMint,
          surfaceContainerHighest: AppColors.outline,
          outline: AppColors.textSecondary,
          outlineVariant: AppColors.outline,
          surfaceTint: Colors.transparent,
        );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansTC',
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(fontSize: 16, height: 1.5),
        bodySmall: TextStyle(fontSize: 14, height: 1.5),
        labelLarge: TextStyle(fontSize: 16, height: 1.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: AppStyles.primaryButton,
      ),
      filledButtonTheme: FilledButtonThemeData(style: AppStyles.primaryButton),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size(48, 48),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size(48, 48),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surfaceSoft,
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: AppColors.outline,
    );
  }
}

class AppStyles {
  static const double borderRadius = 24.0;
  static const double padding = 24.0;
  static const double contentMaxWidth = 720;
  static double horizontalPadding(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600 ? 16 : 24;
  static ButtonStyle get primaryButton => ElevatedButton.styleFrom(
    backgroundColor: AppColors.accent,
    foregroundColor: Colors.white,
    minimumSize: const Size(48, 52),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    textStyle: const TextStyle(
      fontFamily: 'NotoSansTC',
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w600,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );
}

/// Centers shared mobile content without imposing a fixed height.
class AppContent extends StatelessWidget {
  final Widget child;
  final double verticalPadding;
  const AppContent({super.key, required this.child, this.verticalPadding = 16});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppStyles.contentMaxWidth),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppStyles.horizontalPadding(context),
          vertical: verticalPadding,
        ),
        child: child,
      ),
    ),
  );
}
