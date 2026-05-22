import 'package:flutter/foundation.dart';

class WebHelper {
  /// 獲取網頁安全的圖片網址。如果是在 Web 平台且為外部圖片連結，會透過自建的 Firebase CORS Proxy 繞過 CORS 限制。
  static String getWebSafeUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    
    // 如果是 Web 平台且是網路連結，且非本地資源，就透過內部代理轉發
    if (kIsWeb && url.startsWith('http') && !url.contains('localhost') && !url.contains('127.0.0.1')) {
      // 透過自建的 Firebase Hosting rewrite 路由轉發至 Cloud Function
      // 使用相對路徑，可自動辨識部署後的域名或本地開發伺服器
      return '/cors-proxy?url=${Uri.encodeComponent(url)}';
    }
    return url;
  }
}
