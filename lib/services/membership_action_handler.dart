import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/pet/domain/models/pet_model.dart';
import '../screens/profile/settings_screen.dart';
import '../constants.dart';
import 'auth_service.dart';
import 'ad_service.dart';
import 'error_service.dart';

class MembershipActionHandler {
  final AuthService _authService;
  final AdService _adService;

  MembershipActionHandler(this._authService, this._adService);

  /// 處理開始與 AI 寵物溝通的完整入口決策 (含扣點、廣告、升級判定)
  Future<void> handleStartCommunication(
    BuildContext context,
    PetModel pet, {
    required VoidCallback onAllowed,
  }) async {
    final user = await _authService.getUserData();
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入帳號')),
      );
      return;
    }

    final type = user.membershipType?.toLowerCase() ?? 'free';

    if (type == 'pro') {
      // Pro 會員：無限次溝通，不需要點數，但可能在某些情境展示專屬 Pro 體驗
      onAllowed();
    } else if (type == 'plus') {
      // Plus 會員：需升級至 Pro 才能享受無限次溝通，或者彈出升級提醒
      showUpgradeDialog(context, currentTier: 'plus');
    } else {
      // Free 會員：每次溝通需要 1 PT
      if (user.points > 0) {
        showPointConsumptionDialog(context, pet, onAllowed: onAllowed);
      } else {
        // 沒有點數，引導升級或觀看影片領點數
        showUpgradeDialog(context, currentTier: 'free');
      }
    }
  }

  /// 顯示方案升級對話框
  void showUpgradeDialog(BuildContext context, {required String currentTier}) {
    final String targetTier = currentTier == 'free' ? 'Plus' : 'Pro';
    final Color tierColor = currentTier == 'free' ? Colors.blue : Colors.amber;
    final String title = '解鎖 $targetTier 方案';
    final String message = currentTier == 'free'
        ? '升級至 Plus 方案即可開啟雲端同步並獲得額外點數加成！'
        : '升級至 Pro 尊榮方案，即刻享受無限次 AI 溝通與最優先支援。';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: tierColor),
            const SizedBox(width: 12),
            Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: GoogleFonts.outfit()),
            const SizedBox(height: 16),
            _buildFeatureItem(Icons.cloud_sync_rounded, currentTier == 'free' ? '雲端即時備份與同步' : '雲端最速同步優先權'),
            _buildFeatureItem(Icons.devices_rounded, '跨裝置隨時隨地存取'),
            _buildFeatureItem(Icons.auto_awesome_rounded, currentTier == 'free' ? 'AI 溝通點數加成' : '無限次 AI 寵物溝通'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('稍後再說', style: GoogleFonts.outfit(color: AppColors.textSecondary)),
          ),
          if (currentTier == 'free')
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                showRewardedAdOption(context);
              },
              child: const Text('觀看影片領點數', style: TextStyle(color: AppColors.secondary)),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: tierColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('了解 $targetTier 方案', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// 顯示扣減點數確認對話框
  void showPointConsumptionDialog(
    BuildContext context,
    PetModel pet, {
    required VoidCallback onAllowed,
  }) {
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('開始溝通', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('本次與 ${pet.name} 的溝通將消耗 1 PT 點數。\n升級會員可享優惠或無限次溝通！'),
              if (isProcessing) ...[
                const SizedBox(height: 20),
                const CircularProgressIndicator(color: AppColors.primary),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(ctx),
              child: Text('稍後', style: GoogleFonts.outfit(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: isProcessing
                  ? null
                  : () async {
                      setDialogState(() => isProcessing = true);
                      try {
                        await _authService.consumePoints(1);
                        if (context.mounted) {
                          Navigator.pop(ctx); // 關閉扣點彈窗
                          
                          // 播放非 Pro 會員插頁廣告
                          final user = await _authService.getUserData();
                          if (user != null && (user.membershipType?.toLowerCase() ?? 'free') != 'pro') {
                            await _adService.showInterstitialAd();
                          }
                          
                          onAllowed(); // 允許進行溝通跳轉
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setDialogState(() => isProcessing = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('扣點失敗: ${ErrorService.getErrorMessage(e)}')),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('確認扣點', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// 顯示看影片拿點數確認對話框
  void showRewardedAdOption(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.video_collection_rounded, color: AppColors.secondary),
            const SizedBox(width: 12),
            Text('獲得點數', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('觀看一段短片，即可免費獲得 1 PT 溝通點數！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('稍後再說', style: GoogleFonts.outfit(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _adService.watchAdForPoints(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('觀看影片', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.secondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: GoogleFonts.outfit(fontSize: 14))),
        ],
      ),
    );
  }
}
