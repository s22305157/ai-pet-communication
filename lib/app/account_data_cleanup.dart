import 'package:ai_pet_communication/core/storage/account_cleanup.dart';

class AccountDataCleanup implements AccountCleanup {
  final List<AccountCleanup> stores;
  const AccountDataCleanup(this.stores);
  @override
  Future<void> clearUser(String uid) async {
    for (final store in stores) {
      await store.clearUser(uid);
    }
  }
}
