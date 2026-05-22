import 'package:flutter_test/flutter_test.dart';
import 'package:ai_pet_communication/utils/web_helper.dart';

void main() {
  group('WebHelper.getWebSafeUrl 測試', () {
    test('空網址或 null 應返回空字串', () {
      expect(WebHelper.getWebSafeUrl(null), '');
      expect(WebHelper.getWebSafeUrl(''), '');
    });

    test('本地資源或 localhost 網址不應被代理', () {
      const localAsset = 'assets/images/cat.png';
      expect(WebHelper.getWebSafeUrl(localAsset), localAsset);

      const localHostUrl = 'http://localhost:8080/avatar.png';
      expect(WebHelper.getWebSafeUrl(localHostUrl), localHostUrl);
    });

    test('外部網路圖片在非 Web 平台上不應被代理', () {
      const extUrl = 'https://lh3.googleusercontent.com/a/abc';
      // 預設 Flutter 測試環境中 kIsWeb 為 false
      expect(WebHelper.getWebSafeUrl(extUrl), extUrl);
    });
  });
}
