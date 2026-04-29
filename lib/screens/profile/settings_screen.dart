import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

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
          '設定',
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

          return ListView(
            padding: const EdgeInsets.all(AppStyles.padding),
            children: [
              _buildSectionTitle('帳號與方案'),
              _buildSettingsCard([
                _buildSettingTile(
                  icon: Icons.workspace_premium_rounded,
                  title: '目前方案',
                  trailing: Text(
                    (userModel?.membershipType ?? 'Free').toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: _getTierColor(userModel?.membershipType),
                    ),
                  ),
                ),
                _buildSettingTile(
                  icon: Icons.monetization_on_rounded,
                  title: '當前點數',
                  trailing: Text(
                    '${userModel?.points ?? 0} PT',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                ),
              ]),

              const SizedBox(height: 24),
              _buildSectionTitle('資料與同步'),
              _buildSettingsCard([
                _buildSettingTile(
                  icon: Icons.cloud_sync_rounded,
                  title: '雲端同步狀態',
                  trailing: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                ),
                _buildSettingTile(
                  icon: Icons.delete_sweep_outlined,
                  title: '清除暫存資料',
                  onTap: () => _showClearCacheDialog(context),
                ),
              ]),

              const SizedBox(height: 24),
              _buildSectionTitle('關於'),
              _buildSettingsCard([
                _buildSettingTile(
                  icon: Icons.info_outline_rounded,
                  title: '版本號',
                  trailing: const Text('0.0.3'),
                ),
                _buildSettingTile(
                  icon: Icons.description_outlined,
                  title: '服務條款與隱私權政策',
                  onTap: () {},
                ),
              ]),
            ],
          );
        },
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('清除暫存', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('這將釋放本地快取的圖片空間，不會影響您的雲端資料。', style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: GoogleFonts.outfit(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              // 實作清除快取邏輯
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('暫存已清除')),
              );
            },
            child: Text('確定清除', style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Color _getTierColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'plus': return Colors.blue;
      case 'pro': return Colors.amber;
      default: return Colors.grey;
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary, size: 22),
      title: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 15,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
