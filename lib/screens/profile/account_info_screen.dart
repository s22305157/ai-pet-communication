import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

class AccountInfoScreen extends StatelessWidget {
  const AccountInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '帳號資訊',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<UserModel?>(
        stream: authService.getUserStream(),
        builder: (context, snapshot) {
          final userModel = snapshot.data;
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppStyles.padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('會員與資產'),
                
                // 1. 會員等級
                if (userModel?.membershipType?.toLowerCase() == 'free')
                  _buildUpgradeCard(context, targetTier: 'Plus', nextTier: 'Pro', color: Colors.blue)
                else if (userModel?.membershipType?.toLowerCase() == 'plus')
                  _buildUpgradeCard(context, targetTier: 'Pro', isUpgrade: true, color: Colors.amber)
                else
                  _buildSettingsCard([
                    _buildSettingTile(
                      icon: Icons.workspace_premium_rounded,
                      title: '會員等級',
                      trailing: Text('Pro 尊榮會員', style: GoogleFonts.outfit(color: Colors.amber, fontWeight: FontWeight.bold)),
                      onTap: () {},
                    ),
                  ]),

                const SizedBox(height: 16),

                // 2. 我的點數
                _buildSettingsCard([
                  _buildSettingTile(
                    icon: Icons.pets_rounded,
                    title: '我的點數',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${userModel?.points ?? 0} PT', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        _buildShopButton(context),
                      ],
                    ),
                    onTap: () {},
                  ),
                ]),
                
                const SizedBox(height: 32),
                _buildSectionTitle('交易管理'),
                
                // 3. 訂單紀錄 (移動至此)
                _buildSettingsCard([
                  _buildSettingTile(
                    icon: Icons.receipt_long_outlined,
                    title: '訂單紀錄',
                    onTap: () {},
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary.withOpacity(0.7)),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingTile({required IconData icon, required String title, Widget? trailing, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary, size: 22),
      title: Text(title, style: GoogleFonts.outfit(fontSize: 15, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildUpgradeCard(BuildContext context, {required String targetTier, String? nextTier, bool isUpgrade = false, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.8), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isUpgrade ? Icons.trending_up_rounded : Icons.workspace_premium_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(
                isUpgrade ? '升級至 $targetTier' : '解鎖 $targetTier 方案',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '享有無廣告體驗、雲端同步與 AI 加成',
            style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.9), fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {}, // 導向購買
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: color,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('立即升級 $targetTier', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildShopButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('點數商城開發中'))),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              '購買點數',
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
        ),
      ),
    );
  }
}
