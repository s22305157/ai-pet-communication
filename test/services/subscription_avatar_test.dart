import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ai_pet_communication/core/session/current_session.dart';
import 'package:ai_pet_communication/models/user_model.dart';
import 'package:ai_pet_communication/features/pet/data/repositories/avatar_upload_repository_impl.dart';
import 'package:ai_pet_communication/features/pet/data/sources/pet_remote_data_source.dart';
import 'package:ai_pet_communication/widgets/avatar_image_loader.dart';

class Session extends Mock implements CurrentSession {}

class Remote extends Mock implements PetRemoteDataSource {}

void main() {
  test(
    'Free avatars stay local and can load without a network request',
    () async {
      final session = Session();
      final remote = Remote();
      when(() => session.getUserData()).thenAnswer(
        (_) async => UserModel(uid: 'a', email: '', displayName: ''),
      );
      final repository = AvatarUploadRepositoryImpl(
        remoteDataSource: remote,
        session: session,
      );
      final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      final uri = await repository.uploadPetAvatar('a', 'image', bytes);
      expect(Uri.parse(uri).data!.contentAsBytes(), bytes);
      final loader = AvatarImageLoader();
      await loader.load(uri);
      expect(loader.bytes, bytes);
      loader.dispose();
      verifyZeroInteractions(remote);
      await expectLater(
        repository.uploadPetAvatar('b', 'image', bytes),
        throwsStateError,
      );
    },
  );
}
