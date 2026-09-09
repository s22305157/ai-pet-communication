import 'package:flutter/material.dart';

import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/features/profile/presentation/points_shop_screen.dart';
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

  /// 所有升級入口都導向同一份方案預覽。
  void showUpgradeDialog(BuildContext context, {required String currentTier}) {
    PointsShopScreen.open(
      context,
      initialOffer: currentTier == 'free' ? 'plus' : 'pro',
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
}
