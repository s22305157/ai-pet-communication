import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

Future<void> initializeAppCheck() async {
  const enabled = bool.fromEnvironment('APP_CHECK_ENABLED');
  if (!enabled) return;
  const siteKey = String.fromEnvironment('APP_CHECK_WEB_SITE_KEY');
  if (kIsWeb && siteKey.isEmpty) throw StateError('App Check 網頁站點金鑰尚未設定');
  await FirebaseAppCheck.instance.activate(
    providerWeb: kIsWeb ? ReCaptchaV3Provider(siteKey) : null,
  );
}
