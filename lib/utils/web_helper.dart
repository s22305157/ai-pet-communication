import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WebHelper {
  static const _proxyHost = 'lh3.googleusercontent.com';

  /// 只讓 Web 版的 Google 登入頭像經過受保護的圖片代理。
  static bool shouldProxy(String url) {
    final uri = Uri.tryParse(url);
    return kIsWeb &&
        uri?.scheme == 'https' &&
        uri?.host.toLowerCase() == _proxyHost;
  }

  static String getWebSafeUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (shouldProxy(url)) {
      return '/cors-proxy?url=${Uri.encodeComponent(url)}';
    }
    return url;
  }

  static Future<Map<String, String>?> getProxyAuthHeaders() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }
}
