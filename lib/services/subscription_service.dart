import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  // ── 配置區域 (請在此填寫您的 RevenueCat API Keys) ──────────────────────────
  static const String _appleApiKey = 'appl_placeholder'; // iOS API Key
  static const String _googleApiKey = 'goog_placeholder'; // Android API Key
  // ────────────────────────────────────────────────────────────────────────

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (kIsWeb) {
        debugPrint('SubscriptionService: Web 平台暫不支援 purchases_flutter');
        return;
      }

      await Purchases.setLogLevel(LogLevel.debug);

      PurchasesConfiguration configuration;
      if (Platform.isAndroid) {
        configuration = PurchasesConfiguration(_googleApiKey);
      } else if (Platform.isIOS) {
        configuration = PurchasesConfiguration(_appleApiKey);
      } else {
        return;
      }

      await Purchases.configure(configuration);
      _isInitialized = true;
      debugPrint('SubscriptionService: RevenueCat 初始化成功');
    } catch (e) {
      debugPrint('SubscriptionService: 初始化失敗 - $e');
    }
  }

  /// 獲取當前用戶的權限狀態
  /// 返回 'free', 'plus', 或 'pro'
  Future<String> checkEntitlementStatus() async {
    if (!_isInitialized) return 'free';

    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      
      // 假設 RevenueCat 中設定的 Entitlement ID 分別為 'plus' 與 'pro'
      if (customerInfo.entitlements.all['pro']?.isActive ?? false) {
        return 'pro';
      } else if (customerInfo.entitlements.all['plus']?.isActive ?? false) {
        return 'plus';
      }
    } catch (e) {
      debugPrint('SubscriptionService: 獲取權限失敗 - $e');
    }

    return 'free';
  }

  /// 發起購買流程
  Future<bool> purchasePackage(Package package) async {
    try {
      CustomerInfo customerInfo = await Purchases.purchasePackage(package);
      return customerInfo.entitlements.all['pro']?.isActive ?? 
             customerInfo.entitlements.all['plus']?.isActive ?? false;
    } catch (e) {
      debugPrint('SubscriptionService: 購買失敗 - $e');
      return false;
    }
  }

  /// 恢復購買
  Future<void> restorePurchases() async {
    try {
      await Purchases.restorePurchases();
    } catch (e) {
      debugPrint('SubscriptionService: 恢復購買失敗 - $e');
    }
  }

  /// 登入 RevenueCat (關聯 App 用戶 ID)
  Future<void> logIn(String uid) async {
    if (!_isInitialized) return;
    try {
      await Purchases.logIn(uid);
    } catch (e) {
      debugPrint('SubscriptionService: RevenueCat 登入失敗 - $e');
    }
  }

  /// 登出 RevenueCat
  Future<void> logOut() async {
    if (!_isInitialized) return;
    try {
      await Purchases.logOut();
    } catch (e) {
      debugPrint('SubscriptionService: RevenueCat 登出失敗 - $e');
    }
  }
}
