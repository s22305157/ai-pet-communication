import 'package:ai_pet_communication/features/pet/application/pet_service.dart';
import 'package:ai_pet_communication/features/pet/application/pet_sync_manager.dart';
import 'package:ai_pet_communication/features/pet/application/pet_stream_watcher.dart';
import 'package:ai_pet_communication/features/pet/domain/repositories/pet_repository.dart';
import 'package:ai_pet_communication/features/pet/domain/repositories/avatar_upload_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class Repository extends Mock implements PetRepository {}

class Avatar extends Mock implements AvatarUploadRepository {}

class Watcher extends Mock implements PetStreamWatcher {}

class Sync extends Mock implements PetSyncManager {}

void main() {
  test(
    'complete injection requires no Firebase/Hive and ignores GetIt',
    () async {
      final repo = Repository();
      when(() => repo.getPet('p')).thenAnswer((_) async => null);
      PetService create() => PetService(
        repository: repo,
        avatarUploadRepository: Avatar(),
        streamWatcher: Watcher(),
        syncManager: Sync(),
      );
      await create().getPet('p');
      GetIt.instance.registerSingleton<PetSyncManager>(Sync());
      try {
        await create().getPet('p');
      } finally {
        await GetIt.instance.reset();
      }
      verify(() => repo.getPet('p')).called(2);
    },
  );
}
