import 'package:flutter/foundation.dart';
import '../../domain/repositories/avatar_upload_repository.dart';
import '../sources/pet_remote_data_source.dart';

class AvatarUploadRepositoryImpl implements AvatarUploadRepository {
  final PetRemoteDataSource _remoteDataSource;

  AvatarUploadRepositoryImpl({
    required PetRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<String> uploadPetAvatar(String uid, String imageId, Uint8List imageBytes) async {
    return await _remoteDataSource.uploadPetAvatar(uid, imageId, imageBytes);
  }
}
