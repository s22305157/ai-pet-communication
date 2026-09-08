import 'dart:typed_data';

abstract class AvatarUploadRepository {
  Future<String> uploadPetAvatar(
    String uid,
    String imageId,
    Uint8List imageBytes,
  );
}
