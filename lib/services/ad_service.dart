import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'auth_service.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  bool _isRewardedAdLoading = false;
  bool _isInterstitialAdLoading = false;

  // ── 測試廣告 ID (正式發布時請替換) ──────────────────────────────────────────
  final String _rewardedAdUnitId = kIsWeb
      ? '' 
      : (defaultTargetPlatform == TargetPlatform.android
          ? 'ca-app-pub-3940256099942544/5224354917' 
          : 'ca-app-pub-3940256099942544/1712485313'); 

  final String _interstitialAdUnitId = kIsWeb
      ? ''
      : (defaultTargetPlatform == TargetPlatform.android
          ? 'ca-app-pub-3940256099942544/1033173712'
          : 'ca-app-pub-3940256099942544/4411468910');
  // ────────────────────────────────────────────────────────────────────────

  /// 初始化 Mobile Ads SDK
  Future<void> initialize() async {
    if (kIsWeb) return;
    await MobileAds.instance.initialize();
    loadRewardedAd();
    loadInterstitialAd();
  }

  /// 載入激勵廣告
  void loadRewardedAd() {
    if (_isRewardedAdLoading || _rewardedAd != null) return;
    _isRewardedAdLoading = true;

    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AdService: 激勵廣告載入成功');
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
          
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              loadRewardedAd();
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
          _isRewardedAdLoading = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  /// 載入插頁式廣告
  void loadInterstitialAd() {
    if (_isInterstitialAdLoading || _interstitialAd != null) return;
    _isInterstitialAdLoading = true;

    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AdService: 插頁式廣告載入成功');
          _interstitialAd = ad;
          _isInterstitialAdLoading = false;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('AdService: 插頁式廣告載入失敗 - $error');
          _isInterstitialAdLoading = false;
          _interstitialAd = null;
        },
      ),
    );
  }

  /// 顯示插頁式廣告
  Future<void> showInterstitialAd() async {
    if (_interstitialAd == null) {
      debugPrint('AdService: 插頁式廣告尚未準備就緒');
      loadInterstitialAd();
      return;
    }
    await _interstitialAd!.show();
  }

  /// 顯示激勵廣告並處理獎勵
  Future<void> showRewardedAd({required Function(RewardItem) onReward}) async {
    if (_rewardedAd == null) {
      debugPrint('AdService: 廣告尚未準備就緒');
      loadRewardedAd();
      return;
    }

    await _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        debugPrint('AdService: 用戶獲得獎勵 - ${reward.amount} ${reward.type}');
        onReward(reward);
      },
    );
  }

  /// 輔助方法：看廣告領 1 PT
  Future<void> watchAdForPoints(BuildContext context) async {
    if (_rewardedAd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('影片廣告準備中，請稍後再試')),
      );
      loadRewardedAd();
      return;
    }

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
