import 'package:ai_pet_communication/features/profile/presentation/points_shop_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../models/user_model.dart';
import 'package:ai_pet_communication/features/auth/application/auth_service.dart';
import '../../../../../services/ad_service.dart';
import '../../../../../services/membership_action_handler.dart';
import '../../../../../features/pet/application/pet_service.dart';
import '../../../../../widgets/authenticated_network_image.dart';
import 'package:ai_pet_communication/app/theme.dart';
import 'package:ai_pet_communication/features/profile/presentation/profile_screen.dart';

class HomeTopBar extends StatelessWidget {
  final UserModel user;
  final AuthService authService;
  final PetService petService;
  final AdService adService;
  final MembershipActionHandler membershipHandler;

  const HomeTopBar({
    super.key,
    required this.user,
    required this.authService,
    required this.petService,
    required this.adService,
    required this.membershipHandler,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左側：用戶頭像與問候
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                },
                child: StreamBuilder<UserModel?>(
                  stream: authService.getUserStream(),
                  builder: (context, userSnap) {
                    final tier =
                        userSnap.data?.membershipType.toLowerCase() ?? 'free';
                    final borderColor = tier == 'pro'
                        ? AppColors.secondary
                        : tier == 'plus'
                        ? Colors.blue
                        : Colors.grey.shade400;
                    final photoUrl = userSnap.data?.photoURL ?? user.photoURL;
                    return Hero(
                      tag: 'profile_avatar',
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor, width: 2.5),
                        ),
                        child: Container(
                          width: 44,
                          height: 44,
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
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: borderColor,
                                        ),
                                      ),
                                    ),
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.person_rounded,
                                        color: borderColor,
                                        size: 26,
                                      );
                                    },
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return Center(
                                            child: SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: borderColor,
                                              ),
                                            ),
                                          );
                                        },
                                  )
                                : Icon(
                                    Icons.person_rounded,
                                    color: borderColor,
                                    size: 26,
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StreamBuilder<UserModel?>(
                    stream: authService.getUserStream(),
                    builder: (context, userSnap) {
                      final tier =
                          userSnap.data?.membershipType.toLowerCase() ?? 'free';
                      final nameColor = tier == 'pro'
                          ? AppColors.accent
                          : tier == 'plus'
                          ? Colors.blue.shade700
                          : AppColors.textPrimary;
                      final firestoreName = userSnap.data?.displayName;
                      final authName = user.displayName;

                      // 優先順序：Firestore 名稱 -> Auth 名稱 -> 預設名稱
                      String displayName = '毛小孩主人';
                      if (firestoreName != null && firestoreName.isNotEmpty) {
                        displayName = firestoreName;
                      } else if (authName.isNotEmpty) {
                        displayName = authName;
                      }

                      return Row(
                        children: [
                          Text(
                            displayName,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: nameColor,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          // 右側區塊：同步狀態與點數
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // P2: 同步與資料來源提示 UI
              ValueListenableBuilder<bool>(
                valueListenable: petService.isSyncing,
                builder: (context, isSyncing, _) {
                  if (isSyncing) {
                    return const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.secondary,
                          ),
                        ),
                      ),
                    );
                  }

                  return ValueListenableBuilder<bool>(
                    valueListenable: petService.isCloudActive,
                    builder: (context, isCloud, _) {
                      return StreamBuilder<UserModel?>(
                        stream: authService.getUserStream(),
                        builder: (context, userSnap) {
                          final hasCloudSupport =
                              userSnap.data?.membershipType != 'free';

                          // 根據狀態決定顏色與圖示
                          Color iconColor;
                          IconData iconData;
                          String tooltip;

                          if (!hasCloudSupport) {
                            iconColor = AppColors.textSecondary.withValues(
                              alpha: 0.5,
                            );
                            iconData = Icons.storage_rounded;
                            tooltip = '本地儲存模式 (Free)';
                          } else if (!isCloud) {
                            iconColor = AppColors.accent;
                            iconData = Icons.cloud_off_rounded;
                            tooltip = '連線中斷，切換至本地模式';
                          } else {
                            iconColor = Colors.green.shade400;
                            iconData = Icons.cloud_done_rounded;
                            tooltip = '雲端同步已開啟 (Plus/Pro)';
                          }

                          return Container(
                            margin: const EdgeInsets.only(right: 12),
                            child: Tooltip(
                              message: tooltip,
                              child: InkWell(
                                onTap: () {
                                  if (!hasCloudSupport) {
                                    membershipHandler.showUpgradeDialog(
                                      context,
                                      currentTier: 'free',
                                    );
                                  } else if (!isCloud) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('目前網路不穩，已自動啟動本地保護機制'),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('您的資料已由雲端安全守護'),
                                      ),
                                    );
                                  }
                                },
                                child: Icon(
                                  iconData,
                                  size: 20,
                                  color: iconColor,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
              // 即時點數顯示 (Point Pill)
              StreamBuilder<UserModel?>(
                stream: authService.getUserStream(),
                builder: (context, snapshot) {
                  final userObj = snapshot.data;
                  final points = userObj?.points ?? 0;

                  return PointsBalanceButton(
                    points: points,
                    onPressed: () => PointsShopScreen.open(context),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
