import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'auth_service.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;

  // ── 測試廣告 ID (正式發布時請替換) ──────────────────────────────────────────
  final String _rewardedAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/5224354917' // Android Test ID
      : 'ca-app-pub-3940256099942544/1712485313'; // iOS Test ID
  // ────────────────────────────────────────────────────────────────────────

  /// 初始化 Mobile Ads SDK
  Future<void> initialize() async {
    if (kIsWeb) return;
    await MobileAds.instance.initialize();
    loadRewardedAd();
  }

  /// 載入激勵廣告
  void loadRewardedAd() {
    if (_isAdLoading || _rewardedAd != null) return;
    _isAdLoading = true;

    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AdService: 激勵廣告載入成功');
          _rewardedAd = ad;
          _isAdLoading = false;
          
          // 設定廣告全屏回調
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              loadRewardedAd(); // 關閉後自動載入下一個
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedAd = null;
              loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('AdService: 激勵廣告載入失敗 - $error');
          _isAdLoading = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  /// 顯示激勵廣告並處理獎勵
  Future<void> showRewardedAd({required Function(RewardItem) onReward}) async {
    if (_rewardedAd == null) {
      debugPrint('AdService: 廣告尚未準備就緒');
      loadRewardedAd();
      return;
    }

    // 如果需要 Server-Side Verification (SSV)，可以在此設定
    // await _rewardedAd!.setServerSideVerificationOptions(
    //   ServerSideVerificationOptions(userId: 'user_id_here', customData: 'extra_info'),
    // );

    await _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        debugPrint('AdService: 用戶獲得獎勵 - ${reward.amount} ${reward.type}');
        onReward(reward);
      },
    );
  }

  /// 輔助方法：看廣告領 1 PT
  Future<void> watchAdForPoints(BuildContext context) async {
    await showRewardedAd(
      onReward: (reward) async {
        try {
          final authService = AuthService();
          await authService.addPoints(1); // 增加 1 點
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('恭喜獲得 1 PT 點數！')),
            );
          }
        } catch (e) {
          debugPrint('AdService: 獎勵發放失敗 - $e');
        }
      },
    );
  }
}
