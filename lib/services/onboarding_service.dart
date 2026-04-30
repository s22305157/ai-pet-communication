import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/onboarding_model.dart';

class OnboardingService {
  static const String _keyCompleted = 'onboarding_completed';
  static const String _keyAnswers = 'onboarding_answers';

  /// 檢查用戶是否已完成新手引導
  Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyCompleted) ?? false;
  }

  /// 標記新手引導為完成
  Future<void> markCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCompleted, completed);
  }

  /// 儲存問卷答案
  Future<void> saveAnswers(List<OnboardingAnswer> answers) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> data = {
      for (var a in answers) a.questionId: a.value
    };
    await prefs.setString(_keyAnswers, jsonEncode(data));
  }

  /// 獲取儲存的答案
  Future<Map<String, dynamic>> getSavedAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_keyAnswers);
    if (jsonStr == null) return {};
    return jsonDecode(jsonStr);
  }
}
