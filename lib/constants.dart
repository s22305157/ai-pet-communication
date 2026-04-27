import 'package:flutter/material.dart';

class AppColors {
  // PawLink Light Theme Colors
  static const Color primary = Color(0xFF7BB3D1); // Light Blue from logo
  static const Color secondary = Color(0xFF7EC8B7); // Light Teal from logo
  static const Color accent = Color(0xFF2D4A5E); // Dark Slate Blue for accents
  
  static const Color background = Colors.white; // Clean white background
  static const Color surface = Colors.white; // White surface
  
  static const Color textPrimary = Color(0xFF2D4A5E); // Dark Slate Blue for main text
  static const Color textSecondary = Color(0xFF5A7A8E); // Lighter Slate Blue

  // Gradient for background (subtle light gradient matching the logo vibe)
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF0F8FF), // Alice Blue
      Color(0xFFE0F2F1), // Very light teal
    ],
  );
}

class AppStyles {
  static const double borderRadius = 24.0;
  static const double padding = 24.0;
}
