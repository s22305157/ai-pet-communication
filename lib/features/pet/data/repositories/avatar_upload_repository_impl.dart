import 'package:flutter/foundation.dart';
import 'package:ai_pet_communication/core/session/current_session.dart';
import 'package:ai_pet_communication/features/pet/domain/repositories/avatar_upload_repository.dart';
import 'package:ai_pet_communication/features/pet/data/sources/pet_remote_data_source.dart';

class AvatarUploadRepositoryImpl implements AvatarUploadRepository {
  final PetRemoteDataSource _remoteDataSource;
  final CurrentSession _session;

  AvatarUploadRepositoryImpl({
    required PetRemoteDataSource remoteDataSource,
    required CurrentSession session,
  }) : _remoteDataSource = remoteDataSource,
       _session = session;

  @override
  Future<String> uploadPetAvatar(
    String uid,
    String imageId,
    Uint8List imageBytes,
  ) async {
    final user = await _session.getUserData();
    if (user?.uid != uid) throw StateError('帳號已變更');
    if (user!.membershipTier == 'free') {
      if (imageBytes.length > PetRemoteDataSource.maxAvatarSizeBytes) {
        throw ArgumentError('Pet avatar must not exceed 10 MiB.');
      }
      // Keep a downgraded account usable without a paid Storage write.
      return Uri.dataFromBytes(
        imageBytes,
        mimeType: 'application/octet-stream',
      ).toString();
    }
    return await _remoteDataSource.uploadPetAvatar(uid, imageId, imageBytes);
  }
}
