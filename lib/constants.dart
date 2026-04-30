import 'package:flutter/material.dart';

class AppColors {
  // PAWLINK 淺色主題配色 (AI Pet Communicator)
  static const Color primary = Color(0xFF7BB3D1); // 標誌中的淺藍色
  static const Color secondary = Color(0xFF7EC8B7); // 標誌中的淺藍綠色
  static const Color accent = Color(0xFF2D4A5E); // 深石板藍（用於強調）
  
  static const Color background = Colors.white; // 純白背景
  static const Color surface = Colors.white; // 表面顏色
  
  static const Color textPrimary = Color(0xFF2D4A5E); // 主要文本色（深石板藍）
  static const Color textSecondary = Color(0xFF5A7A8E); // 次要文本色（淺石板藍）

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

class AppStyles {
  static const double borderRadius = 24.0;
  static const double padding = 24.0;
}
