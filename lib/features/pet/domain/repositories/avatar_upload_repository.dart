import 'package:flutter/foundation.dart';

abstract class AvatarUploadRepository {
  Future<String> uploadPetAvatar(String uid, String imageId, Uint8List imageBytes);
}
