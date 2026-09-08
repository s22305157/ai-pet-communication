import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/features/profile/presentation/settings_screen.dart';
import 'package:ai_pet_communication/app/theme.dart';
import 'package:ai_pet_communication/features/auth/application/auth_service.dart';
import 'package:ai_pet_communication/services/ad_service.dart';
import 'package:ai_pet_communication/services/credit_service.dart';

typedef CommunicationAllowed = void Function(String? creditReservationId);

class MembershipActionHandler {
  final AuthService _authService;

  MembershipActionHandler(
    this._authService,
    AdService adService,
    CreditService creditService,
  );

  /// 收費待精算，登入後進入溝通；後端負責會員分流與試用配額。
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

    // 收費待精算：不檢查餘額、不預留點數；後端仍驗證方案及用量。
    onAllowed(null);
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

  /// 舊入口亦不預留點數，等待正式費率設定。
  void showPointConsumptionDialog(
    BuildContext context,
    PetModel pet, {
    required CommunicationAllowed onAllowed,
  }) {
    onAllowed(null);
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
