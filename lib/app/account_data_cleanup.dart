import 'package:ai_pet_communication/core/storage/account_cleanup.dart';

class AccountDataCleanup implements AccountCleanup {
  final List<AccountCleanup> stores;
  const AccountDataCleanup(this.stores);
  @override
  Future<void> clearUser(String uid) async {
    Object? failure;
    StackTrace? failureStack;
    for (final store in stores) {
      try {
        await store.clearUser(uid);
      } catch (error, stack) {
        failure ??= error;
        failureStack ??= stack;
      }
    }
    if (failure != null) Error.throwWithStackTrace(failure, failureStack!);
  }
}
