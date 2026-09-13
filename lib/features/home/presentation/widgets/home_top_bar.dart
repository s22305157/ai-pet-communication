import 'package:flutter/material.dart';
import 'package:ai_pet_communication/app/theme.dart';
import 'package:ai_pet_communication/features/profile/presentation/points_shop_screen.dart';
import 'package:ai_pet_communication/features/profile/presentation/profile_screen.dart';
import 'package:ai_pet_communication/features/auth/application/auth_service.dart';
import 'package:ai_pet_communication/features/pet/application/pet_service.dart';
import 'package:ai_pet_communication/models/user_model.dart';
import 'package:ai_pet_communication/services/ad_service.dart';
import 'package:ai_pet_communication/services/membership_action_handler.dart';
import 'package:ai_pet_communication/widgets/authenticated_network_image.dart';

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
  Widget build(BuildContext context) => StreamBuilder<UserModel?>(
    stream: authService.getUserStream(),
    builder: (context, snapshot) {
      final current = snapshot.data;
      final tier = current?.membershipType.toLowerCase() ?? 'free';
      final name = current?.displayName.isNotEmpty == true
          ? current!.displayName
          : user.displayName.isNotEmpty
          ? user.displayName
          : '毛小孩主人';
      final photo = current?.photoURL ?? user.photoURL;
      final profile = Row(
        children: [
          Semantics(
            button: true,
            label: '開啟個人頁，$name',
            excludeSemantics: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
            ),
            child: Tooltip(
              message: '個人頁',
              child: InkWell(
                key: const Key('open-profile'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ProfileScreen(),
                  ),
                ),
                borderRadius: BorderRadius.circular(30),
                child: Hero(
                  tag: 'profile_avatar',
                  child: Container(
                    width: 56,
                    height: 56,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceSoft,
                      border: Border.all(
                        color: tier == 'pro'
                            ? AppColors.secondary
                            : AppColors.primary,
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: photo != null && photo.isNotEmpty
                          ? AuthenticatedNetworkImage(
                              url: photo,
                              fit: BoxFit.cover,
                              authLoadingPlaceholder: const Icon(
                                Icons.person_rounded,
                              ),
                              errorBuilder: (_, error, stack) =>
                                  const Icon(Icons.person_rounded),
                              loadingBuilder: (_, child, progress) =>
                                  progress == null
                                  ? child
                                  : const Icon(Icons.person_rounded),
                            )
                          : const Icon(
                              Icons.person_rounded,
                              color: AppColors.accent,
                              size: 28,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      );
      final status = Row(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: petService.isSyncing,
            builder: (context, syncing, _) => syncing
                ? const SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          semanticsLabel: '正在同步資料',
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  )
                : ValueListenableBuilder<bool>(
                    valueListenable: petService.isCloudActive,
                    builder: (context, cloud, _) {
                      final supported = tier != 'free';
                      final label = !supported
                          ? '本地儲存模式 (Free)'
                          : cloud
                          ? '雲端同步已開啟 (Plus/Pro)'
                          : '連線中斷，切換至本地模式';
                      return IconButton(
                        key: const Key('sync-status'),
                        tooltip: label,
                        icon: Icon(
                          !supported
                              ? Icons.storage_rounded
                              : cloud
                              ? Icons.cloud_done_rounded
                              : Icons.cloud_off_rounded,
                        ),
                        onPressed: () {
                          if (!supported) {
                            membershipHandler.showUpgradeDialog(
                              context,
                              currentTier: 'free',
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  cloud ? '您的資料已由雲端安全守護' : '目前網路不穩，已自動啟動本地保護機制',
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: PointsBalanceButton(
                points: current?.points ?? 0,
                onPressed: () => PointsShopScreen.open(context),
              ),
            ),
          ),
        ],
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: MediaQuery.sizeOf(context).width < 600
            ? Column(children: [profile, const SizedBox(height: 8), status])
            : Row(
                children: [
                  Expanded(child: profile),
                  const SizedBox(width: 16),
                  Expanded(child: status),
                ],
              ),
      );
    },
  );
}
