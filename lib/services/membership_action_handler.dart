import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../features/pet/domain/models/pet_model.dart';
import '../screens/profile/settings_screen.dart';
import '../constants.dart';
import 'auth_service.dart';
import 'ad_service.dart';
import 'error_service.dart';
import 'credit_service.dart';

typedef CommunicationAllowed = void Function(String? creditReservationId);

class MembershipActionHandler {
  final AuthService _authService;
  final AdService _adService;
  final CreditService _creditService;

  MembershipActionHandler(
    this._authService,
    this._adService,
    this._creditService,
  );

  /// 處理開始與 AI 寵物溝通的完整入口決策 (含扣點、廣告、升級判定)
  Future<void> handleStartCommunication(
    BuildContext context,
    PetModel pet, {
    required CommunicationAllowed onAllowed,
  }) async {
    final user = await _authService.getUserData();
    if (!context.mounted) return;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先登入帳號')));
      return;
    }

    final type = user.membershipType.toLowerCase();

    if (type == 'pro') {
      // Pro 會員：無限次溝通，不需要點數，但可能在某些情境展示專屬 Pro 體驗
      onAllowed(null);
    } else if (type == 'plus') {
      // Plus 會員：需升級至 Pro 才能享受無限次溝通，或者彈出升級提醒
      showUpgradeDialog(context, currentTier: 'plus');
    } else {
      // Free 會員：每次溝通需要 1 PT
      if (user.points > 0) {
        showPointConsumptionDialog(context, pet, onAllowed: onAllowed);
      } else {
        // 沒有點數，引導升級
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
            _buildFeatureItem(
              Icons.cloud_sync_rounded,
              currentTier == 'free' ? '雲端即時備份與同步' : '雲端最速同步優先權',
            ),
            _buildFeatureItem(Icons.devices_rounded, '跨裝置隨時隨地存取'),
            _buildFeatureItem(
              Icons.auto_awesome_rounded,
              currentTier == 'free' ? 'AI 溝通點數加成' : '無限次 AI 寵物溝通',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              '稍後再說',
              style: GoogleFonts.outfit(color: AppColors.textSecondary),
            ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              '了解 $targetTier 方案',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 顯示扣減點數確認對話框
  void showPointConsumptionDialog(
    BuildContext context,
    PetModel pet, {
    required CommunicationAllowed onAllowed,
  }) {
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            '開始溝通',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('本次與 ${pet.name} 的溝通會先預留 1 PT。\n完成 AI 溝通後才結算；取消或失敗會退回。'),
              if (isProcessing) ...[
                const SizedBox(height: 20),
                const CircularProgressIndicator(color: AppColors.primary),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(ctx),
              child: Text(
                '稍後',
                style: GoogleFonts.outfit(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: isProcessing
                  ? null
                  : () async {
                      setDialogState(() => isProcessing = true);
                      String? reservationId;
                      try {
                        reservationId = const Uuid().v4();
                        final reservation = await _creditService
                            .reserveCommunication(
                              requestId: reservationId,
                              petId: pet.petId,
                            );
                        reservationId = reservation.requestId;
                        if (!context.mounted) {
                          await _creditService.releaseCommunication(
                            reservationId,
                          );
                          return;
                        }
                        Navigator.pop(ctx); // 關閉點數預留彈窗

                        // 廣告失敗不應吞掉已取得的使用資格。
                        try {
                          await _adService.showInterstitialAd();
                        } catch (_) {}

                        if (!context.mounted) {
                          await _creditService.releaseCommunication(
                            reservationId,
                          );
                          return;
                        }
                        onAllowed(reservationId); // 允許進行溝通跳轉
                      } catch (e) {
                        if (reservationId != null) {
                          try {
                            await _creditService.releaseCommunication(
                              reservationId,
                            );
                          } catch (_) {
                            // 後端操作具冪等性；下次可使用同一 request ID 重試。
                          }
                        }
                        if (ctx.mounted) {
                          setDialogState(() => isProcessing = false);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '點數預留失敗: ${ErrorService.getErrorMessage(e)}',
                              ),
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                '確認並預留',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
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
