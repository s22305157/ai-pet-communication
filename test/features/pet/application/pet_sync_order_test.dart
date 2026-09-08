import 'dart:async';
import 'package:ai_pet_communication/features/pet/application/pet_sync_manager.dart';
import 'package:ai_pet_communication/features/pet/data/local_pet_service.dart';
import 'package:ai_pet_communication/features/pet/data/sources/pet_remote_data_source.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class Local extends Mock implements LocalPetService {}

class Remote extends Mock implements PetRemoteDataSource {}

void main() {
  test(
    'same uid snapshots are serial; other uid remains independent',
    () async {
      final local = Local();
      final manager = PetSyncManager(
        localService: local,
        remoteDataSource: Remote(),
      );
      final blocked = Completer<void>();
      final started = Completer<void>();
      final order = <String>[];
      when(() => local.getAllPets(any())).thenReturn([]);
      when(() => local.getPendingOperations(any())).thenReturn([]);
      var count = 0;
      when(() => local.reconcileCloudSnapshot(any(), any())).thenAnswer((
        call,
      ) async {
        final uid = call.positionalArguments.first as String;
        order.add(uid);
        if (uid == 'a' && count++ == 0) {
          started.complete();
          await blocked.future;
        }
      });
      final first = manager.applyCloudSnapshot('a', <PetModel>[]);
      await started.future;
      var secondDone = false;
      final second = manager
          .applyCloudSnapshot('a', <PetModel>[])
          .then((_) => secondDone = true);
      await manager.applyCloudSnapshot('b', <PetModel>[]);
      expect(order, ['a', 'b']);
      expect(secondDone, false);
      blocked.complete();
      await Future.wait([first, second]);
      expect(order, ['a', 'b', 'a']);
      manager.dispose();
    },
  );

  test(
    'additional synchronization awaits its actual run; failure does not poison queue',
    () async {
      final local = Local();
      final manager = PetSyncManager(
        localService: local,
        remoteDataSource: Remote(),
      );
      final block = Completer<void>();
      final entered = Completer<void>();
      when(() => local.migrateLegacyDataForUser('a')).thenAnswer((_) async {
        entered.complete();
        await block.future;
        throw StateError('failed migration');
      });
      var syncReads = 0;
      when(() => local.getPendingOperations('a')).thenAnswer((_) {
        syncReads++;
        return [];
      });
      final first = manager.migrateIfNeeded('a');
      final expectedFailure = expectLater(first, throwsStateError);
      await entered.future;
      final second = manager.syncPendingOperations('a');
      expect(syncReads, 0);
      block.complete();
      await expectedFailure;
      await second;
      expect(syncReads, 1);
      manager.dispose();
    },
  );

  test('old and cancelled sessions cannot change current cloud status', () {
    final manager = PetSyncManager(
      localService: Local(),
      remoteDataSource: Remote(),
    );
    final a = manager.beginSession('a');
    final b = manager.beginSession('b');
    manager.reportCloud('b', b, true);
    manager.reportCloud('a', a, false);
    expect(manager.isCloudActive.value, true);
    manager.endSession('b', b);
    manager.reportCloud('b', b, false);
    expect(manager.isCloudActive.value, true);
    manager.dispose();
  });
}
