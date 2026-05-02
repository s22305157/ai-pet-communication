import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../services/error_service.dart';

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
          final user = snapshot.data;
          final type = user?.membershipType?.toLowerCase() ?? 'free';

          return ListView(
            padding: const EdgeInsets.all(AppStyles.padding),
            children: [
              const SizedBox(height: 16),
              _buildSectionTitle('資料與同步'),
              _buildSettingsCard([
                _buildSettingTile(
                  icon: Icons.cloud_sync_rounded,
                  title: '雲端同步狀態',
                  trailing: Icon(
                    type == 'free' ? Icons.cloud_off_rounded : Icons.check_circle_rounded,
                    color: type == 'free' ? Colors.grey : Colors.green,
                    size: 20
                  ),
                ),
                _buildSettingTile(
                  icon: Icons.delete_sweep_outlined,
                  title: '清除暫存資料',
                  onTap: () => _showClearCacheDialog(context),
                ),
              ]),

              const SizedBox(height: 32),
              _buildSectionTitle('關於與測試'),
              _buildSettingsCard([
                _buildSettingTile(
                  icon: Icons.info_outline_rounded,
                  title: '版本號',
                  trailing: const Text('0.0.7'),
                ),
                _buildSettingTile(
                  icon: Icons.bug_report_outlined,
                  title: '模擬切換方案 (測試用)',
                  onTap: () => _showTestTierDialog(context, authService),
                ),
              ]),
              
              const SizedBox(height: 40),
              _buildLogoutButton(context, authService),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthService authService) {
    return Center(
      child: TextButton.icon(
        onPressed: () async {
          await authService.signOut();
          if (context.mounted) Navigator.pop(context);
        },
        icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
        label: Text('登出帳號', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _showTestTierDialog(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('選擇測試方案'),
        children: [
          _buildTierOption(context, authService, 'free', 'Free (本地)'),
          _buildTierOption(context, authService, 'plus', 'Plus (雲端)'),
          _buildTierOption(context, authService, 'pro', 'Pro (尊榮)'),
        ],
      ),
    );
  }

  Widget _buildTierOption(BuildContext context, AuthService authService, String type, String label) {
    return SimpleDialogOption(
      onPressed: () async {
        await authService.updateMembership(type);
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(label, style: GoogleFonts.outfit(fontSize: 16)),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暫存已清除')));
            },
            child: const Text('確定', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
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
}
