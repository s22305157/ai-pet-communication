import 'package:flutter/foundation.dart';

class WebHelper {
  /// 獲取網頁安全的圖片網址。如果是在 Web 平台且為外部圖片連結，會透過 weserv.nl 圖片代理伺服器繞過 CORS 限制。
  static String getWebSafeUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    
    // 如果是 Web 平台且是網路連結，且非本地資源，就透過圖片代理轉發
    if (kIsWeb && url.startsWith('http') && !url.contains('localhost') && !url.contains('127.0.0.1')) {
      // 透過 weserv.nl 圖片代理繞過 Web CORS
      return 'https://images.weserv.nl/?url=${Uri.encodeComponent(url)}';
    }
    return url;
  }
}
