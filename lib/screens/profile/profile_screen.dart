import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
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
          '個人帳號',
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
              children: [
                const SizedBox(height: 20),
                // 用戶大頭照
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getTierColor(userModel?.membershipType).withOpacity(0.4),
                        width: 3,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.surface,
                      backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                      child: user?.photoURL == null 
                          ? const Icon(Icons.person_rounded, size: 50, color: AppColors.primary)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 用戶名稱
                Text(
                  userModel?.displayName ?? user?.displayName ?? '毛小孩主人',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                // 會員等級標籤
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getTierColor(userModel?.membershipType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getTierColor(userModel?.membershipType).withOpacity(0.5)),
                  ),
                  child: Text(
                    (userModel?.membershipType ?? 'free').toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getTierColor(userModel?.membershipType),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                
                // 資訊卡片
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildInfoItem(Icons.email_outlined, 'Email', user?.email ?? '-'),
                      const Divider(height: 30),
                      _buildInfoItem(Icons.monetization_on_outlined, '當前點數', '${userModel?.points ?? 0} PT'),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                
                // 選單列表
                _buildMenuItem(
                  icon: Icons.account_circle_outlined,
                  title: '帳號資訊',
                  onTap: () {},
                ),
                _buildMenuItem(
                  icon: Icons.notifications_none_rounded,
                  title: '通知設定',
                  onTap: () {},
                ),
                _buildMenuItem(
                  icon: Icons.receipt_long_outlined,
                  title: '訂單紀錄',
                  onTap: () {},
                ),
                _buildMenuItem(
                  icon: Icons.report_problem_outlined,
                  title: '問題回報',
                  onTap: () {},
                ),
                _buildMenuItem(
                  icon: Icons.settings_outlined,
                  title: '設定',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    );
                  },
                ),

                const SizedBox(height: 40),
                
                // 登出按鈕 (中性色)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await authService.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('登出帳號'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: AppColors.textPrimary.withOpacity(0.2), width: 1),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 刪除帳號按鈕 (警示紅)
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _showDeleteConfirmDialog(context, authService),
                    icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                    label: const Text('永久刪除帳號'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Colors.redAccent, width: 1),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                Text(
                  '版本號 0.0.3',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('刪除帳號', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('確定要永久刪除帳號嗎？此操作不可逆，您的所有資料與點數都將被清除。', style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: GoogleFonts.outfit(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              try {
                await authService.deleteAccount();
                if (context.mounted) {
                  Navigator.of(context).pop(); // 關閉對話框
                  Navigator.of(context).pop(); // 關閉個人頁
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('刪除失敗，請重新登入後再試: $e')),
                  );
                  Navigator.pop(context);
                }
              }
            },
            child: Text('確定刪除', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Text(label, style: GoogleFonts.outfit(color: AppColors.textSecondary)),
        const Spacer(),
        Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildMenuItem({required IconData icon, required String title, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textPrimary),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textSecondary),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
