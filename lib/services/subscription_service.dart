import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionService with WidgetsBindingObserver {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  static const _appleApiKey = String.fromEnvironment(
    'REVENUECAT_APPLE_API_KEY',
  );
  static const _googleApiKey = String.fromEnvironment(
    'REVENUECAT_GOOGLE_API_KEY',
  );
  bool _started = false;
  bool _isInitialized = false;
  String? _sdkUid;
  Future<void> _accountQueue = Future.value();
  Timer? _refreshTimer;

  Future<void> initialize() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) {
      final key = defaultTargetPlatform == TargetPlatform.iOS
          ? _appleApiKey
          : defaultTargetPlatform == TargetPlatform.android
          ? _googleApiKey
          : '';
      if (key.isNotEmpty) {
        try {
          await Purchases.configure(PurchasesConfiguration(key));
          _isInitialized = true;
          Purchases.addCustomerInfoUpdateListener((_) => _scheduleRefresh());
        } catch (_) {
          debugPrint('訂閱商店尚未完成設定，仍會檢查後端會員狀態。');
        }
      }
    }
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _refreshTimer?.cancel();
      // Serialize SDK identity changes so slow login cannot replace a newer account.
      _accountQueue = _accountQueue
          .then((_) async {
            if (FirebaseAuth.instance.currentUser?.uid != user?.uid) return;
            if (_isInitialized) {
              if (user == null) {
                if (_sdkUid != null) await Purchases.logOut();
                _sdkUid = null;
              } else {
                await Purchases.logIn(user.uid);
                _sdkUid = user.uid;
              }
            }
            if (user != null) _scheduleRefresh();
          })
          .catchError((Object _) {
            debugPrint('訂閱帳號同步失敗，將在返回 App 時重試。');
            _scheduleRefresh();
          });
    });
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(seconds: 2), () async {
      if (FirebaseAuth.instance.currentUser == null) return;
      try {
        if (_isInitialized) await _requireStoreAccount();
        await checkEntitlementStatus();
      } catch (_) {
        // Provider failure must not rewrite membership as Free on the client.
        debugPrint('會員同步暫時失敗，稍後重試。');
        _refreshTimer = Timer(const Duration(seconds: 30), _scheduleRefresh);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleRefresh();
  }

  Future<String> checkEntitlementStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 'free';
    final result = await FirebaseFunctions.instance
        .httpsCallable('syncSubscription')
        .call();
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('帳號已變更');
    }
    return (result.data as Map)['membershipTier'] as String;
  }

  Future<void> _requireStoreAccount() async {
    await _accountQueue;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (!_isInitialized || uid == null) throw StateError('請先登入並完成商店設定');
    if (_sdkUid != uid) {
      await Purchases.logIn(uid);
      _sdkUid = uid;
    }
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('帳號已變更');
    }
  }

  Future<bool> purchasePackage(Package package) async {
    await _requireStoreAccount();
    final uid = _sdkUid;
    final info = await Purchases.purchasePackage(package);
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('帳號已變更');
    }
    _scheduleRefresh();
    // SDK confirms purchase only; server-verified Firestore controls access.
    return (info.entitlements.all['pro']?.isActive ?? false) ||
        (info.entitlements.all['plus']?.isActive ?? false);
  }

  Future<void> restorePurchases() async {
    await _requireStoreAccount();
    final uid = _sdkUid;
    await Purchases.restorePurchases();
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('帳號已變更');
    }
    _scheduleRefresh();
  }
}
