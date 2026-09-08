import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:ai_pet_communication/core/session/current_session.dart';
import 'package:ai_pet_communication/core/storage/storage_policy.dart';
import 'package:ai_pet_communication/features/pet/data/local_pet_service.dart';
import 'package:ai_pet_communication/features/pet/data/sources/pet_remote_data_source.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/features/pet/application/pet_sync_manager.dart';

class PetStreamWatcher {
  final PetRemoteDataSource _remoteDataSource;
  final LocalPetService _localService;
  final CurrentSession _authService;
  final PetSyncManager _syncManager;

  PetStreamWatcher({
    required PetRemoteDataSource remoteDataSource,
    required LocalPetService localService,
    required CurrentSession authService,
    required PetSyncManager syncManager,
  }) : _remoteDataSource = remoteDataSource,
       _localService = localService,
       _authService = authService,
       _syncManager = syncManager;

  Stream<List<PetModel>> watchPetsByOwner(String uid) async* {
    final generation = _syncManager.beginSession(uid);
    try {
      yield* _watchSession(uid, generation);
    } finally {
      _syncManager.endSession(uid, generation);
    }
  }

  Stream<List<PetModel>> _watchSession(String uid, int generation) async* {
    final user = await _authService.getUserData();

    if (user == null || user.uid != uid) {
      yield [];
      return;
    }

    if (!const StoragePolicy().usesCloud(user.membershipType)) {
      try {
        await _syncManager.syncPendingOperations(uid, includeUpserts: false);
      } catch (error) {
        debugPrint('Free 帳號的待刪除操作仍離線，稍後重試: $error');
      }
      if ((await _authService.getUserData())?.uid != uid) {
        yield [];
        return;
      }
      yield* _guardActiveUser(uid, _localService.watchPets(uid));
      return;
    }

    try {
      await _syncManager.migrateIfNeeded(uid);
    } catch (_) {
      _syncManager.reportCloud(uid, generation, false);
    }
    final activeUser = await _authService.getUserData();
    if (activeUser == null || activeUser.uid != uid) {
      yield [];
      return;
    }

    yield* _guardActiveUser(uid, _paidPetStream(uid, generation));
  }

  Stream<List<PetModel>> _paidPetStream(String uid, int generation) {
    late final StreamController<List<PetModel>> controller;
    StreamSubscription<List<PetModel>>? cloudSub;
    StreamSubscription<List<PetModel>>? localSub;
    Future<void>? localCancellation;
    var cancelled = false;
    bool active() =>
        !cancelled && _syncManager.isCurrentSession(uid, generation);

    void startLocalFallback() {
      if (!active() || localSub != null) return;
      _syncManager.reportCloud(uid, generation, false);
      localSub = _localService
          .watchPets(uid)
          .listen(
            (data) {
              if (!controller.isClosed) controller.add(data);
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!controller.isClosed) controller.addError(error, stackTrace);
            },
          );
    }

    controller = StreamController<List<PetModel>>(
      onListen: () {
        _syncManager.reportCloud(uid, generation, true);
        cloudSub = _remoteDataSource
            .watchPetsByOwner(uid)
            .asyncMap((snapshot) async {
              if (!active()) return <PetModel>[];
              await _syncManager.applyCloudSnapshot(uid, snapshot);
              if (!active()) return <PetModel>[];
              await _syncManager.syncPendingOperations(uid);
              return _localService.getAllPets(uid);
            })
            .listen(
              (snapshot) async {
                try {
                  if (!active()) return;
                  final fallbackSubscription = localSub;
                  localSub = null;
                  if (fallbackSubscription != null) {
                    localCancellation = fallbackSubscription
                        .cancel()
                        .catchError((Object error) {
                          debugPrint('取消本地降級串流失敗: $error');
                        });
                    unawaited(localCancellation!);
                  }
                  _syncManager.reportCloud(uid, generation, true);
                  if (!controller.isClosed) {
                    controller.add(_localService.getAllPets(uid));
                  }
                } catch (error) {
                  debugPrint('雲端快照同步失敗: $error。使用本地資料。');
                  startLocalFallback();
                }
              },
              onError: (Object error, StackTrace stackTrace) {
                debugPrint('雲端監聽錯誤: $error。啟動本地降級串流。');
                startLocalFallback();
              },
              cancelOnError: false,
            );
      },
      onCancel: () async {
        cancelled = true;
        await cloudSub?.cancel();
        await localSub?.cancel();
        await localCancellation;
      },
    );

    return controller.stream;
  }

  Stream<List<PetModel>> _guardActiveUser(
    String uid,
    Stream<List<PetModel>> source,
  ) {
    late final StreamController<List<PetModel>> controller;
    StreamSubscription<List<PetModel>>? dataSub;
    StreamSubscription<String?>? authSub;
    var stopping = false;

    void stopForAccountChange() {
      if (stopping) return;
      stopping = true;
      unawaited(dataSub?.cancel());
      if (!controller.isClosed) {
        controller.add(const <PetModel>[]);
        unawaited(controller.close());
      }
    }

    controller = StreamController<List<PetModel>>(
      onListen: () {
        authSub = _authService.userIdChanges.listen((activeUid) {
          if (activeUid != uid) stopForAccountChange();
        });
        dataSub = source.listen(
          (pets) {
            if (stopping || controller.isClosed) return;
            controller.add(
              pets.where((pet) => pet.ownerId == uid).toList(growable: false),
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!stopping && !controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          },
        );
      },
      onCancel: () async {
        stopping = true;
        await dataSub?.cancel();
        await authSub?.cancel();
      },
    );

    return controller.stream;
  }
}
