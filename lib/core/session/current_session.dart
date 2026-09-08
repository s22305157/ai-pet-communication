import 'package:ai_pet_communication/models/user_model.dart';

abstract interface class CurrentSession {
  Future<UserModel?> getUserData();
  Stream<String?> get userIdChanges;
}
