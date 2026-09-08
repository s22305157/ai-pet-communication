import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ai_pet_communication/app/theme.dart';
import 'package:ai_pet_communication/features/auth/application/auth_service.dart';
import 'package:ai_pet_communication/models/user_model.dart';
import 'package:ai_pet_communication/app/injection.dart';
import 'package:ai_pet_communication/widgets/authenticated_network_image.dart';
import 'package:ai_pet_communication/features/profile/presentation/account_info_screen.dart';
import 'package:ai_pet_communication/features/profile/presentation/settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String _getNumericId(String? uid) => UserModel.getNumericId(uid);

  void _copyToClipboard(BuildContext context, String? uid) {
    if (uid == null) return;
    final numericId = _getNumericId(uid);
    Clipboard.setData(ClipboardData(text: numericId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('用戶 ID 已複製'),
        backgroundColor: AppColors.secondary,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final authService = getIt<AuthService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '飼主詳情',
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
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
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
                        color: _getTierColor(
                          userModel?.membershipType,
                        ).withValues(alpha: 0.4),
                        width: 3,
                      ),
                    ),
                    child: Builder(
                      builder: (context) {
                        final photoUrl = userModel?.photoURL ?? user?.photoURL;
                        final tierColor = _getTierColor(
                          userModel?.membershipType,
                        );
                        return Container(
                          width: 100,
                          height: 100,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surface,
                          ),
                          child: ClipOval(
                            child: photoUrl != null && photoUrl.isNotEmpty
                                ? AuthenticatedNetworkImage(
                                    url: photoUrl,
                                    fit: BoxFit.cover,
                                    authLoadingPlaceholder: Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: tierColor,
                                        ),
                                      ),
                                    ),
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.person_rounded,
                                        size: 50,
                                        color: tierColor,
                                      );
                                    },
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return Center(
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: tierColor,
                                              ),
                                            ),
                                          );
                                        },
                                  )
                                : Icon(
                                    Icons.person_rounded,
                                    size: 50,
                                    color: tierColor,
                                  ),
                          ),
                        );
                      },
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getTierColor(
                      userModel?.membershipType,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getTierColor(
                        userModel?.membershipType,
                      ).withValues(alpha: 0.5),
                    ),
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

                // 功能選單
                _buildSectionTitle('帳號與設定'),

                // 1. 帳號資訊 (導向獨立頁面)
                _buildMenuItem(
                  icon: Icons.account_circle_outlined,
                  title: '帳號資訊',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AccountInfoScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // 2. 基本資料 (始終顯示)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildSettingsCard([
                    _buildSettingTile(
                      icon: Icons.email_outlined,
                      title: '電子郵件',
                      trailing: Text(
                        user?.email ?? '-',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    _buildSettingTile(
                      icon: Icons.verified_user_outlined,
                      title: '用戶 ID',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getNumericId(user?.uid),
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '複製',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _copyToClipboard(context, user?.uid),
                    ),
                  ]),
                ),

                const SizedBox(height: 24),

                // 3. 其他選單
                _buildMenuItem(
                  icon: Icons.notifications_none_rounded,
                  title: '通知設定',
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
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
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
                        side: BorderSide(
                          color: AppColors.textPrimary.withValues(alpha: 0.2),
                          width: 1,
                        ),
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
                    onPressed: () =>
                        _showDeleteConfirmDialog(context, authService),
                    icon: const Icon(
                      Icons.delete_forever_rounded,
                      color: Colors.redAccent,
                    ),
                    label: const Text('永久刪除帳號'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(
                          color: Colors.redAccent,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                const SizedBox(height: 30),
                Text(
                  '版本號 0.2.0',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
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
        title: Text(
          '刪除帳號',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '確定要永久刪除帳號嗎？此操作不可逆，您的所有資料與點數都將被清除。',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: GoogleFonts.outfit(color: AppColors.textSecondary),
            ),
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
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('刪除失敗，請重新登入後再試: $e')));
                  Navigator.pop(context);
                }
              }
            },
            child: Text(
              '確定刪除',
              style: GoogleFonts.outfit(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary.withValues(alpha: 0.7),
          ),
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
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
          ),
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
      trailing:
          trailing ??
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: AppColors.textSecondary,
          ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Color _getTierColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'plus':
        return Colors.blue;
      case 'pro':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
        trailing:
            trailing ??
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
