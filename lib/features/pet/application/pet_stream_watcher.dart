import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../services/auth_service.dart';
import '../data/local_pet_service.dart';
import '../data/sources/pet_remote_data_source.dart';
import '../domain/models/pet_model.dart';
import 'pet_sync_manager.dart';

class PetStreamWatcher {
  final PetRemoteDataSource _remoteDataSource;
  final LocalPetService _localService;
  final AuthService _authService;
  final PetSyncManager _syncManager;

  PetStreamWatcher({
    required PetRemoteDataSource remoteDataSource,
    required LocalPetService localService,
    required AuthService authService,
    required PetSyncManager syncManager,
  }) : _remoteDataSource = remoteDataSource,
       _localService = localService,
       _authService = authService,
       _syncManager = syncManager;

  Stream<List<PetModel>> watchPetsByOwner(String uid) async* {
    final user = await _authService.getUserData();

    if (user == null || user.uid != uid) {
      yield [];
      return;
    }

    if (user.membershipType == 'free') {
      try {
        await _syncManager.syncPendingOperations(uid, includeUpserts: false);
      } catch (error) {
        debugPrint('Free 帳號的待刪除操作仍離線，稍後重試: $error');
      }
      yield* _guardActiveUser(uid, _localService.watchPets(uid));
      return;
    }

    try {
      await _syncManager.migrateIfNeeded(uid);
    } catch (_) {
      _syncManager.isCloudActive.value = false;
    }
    final activeUser = await _authService.getUserData();
    if (activeUser == null || activeUser.uid != uid) {
      yield [];
      return;
    }

    yield* _guardActiveUser(uid, _paidPetStream(uid));
  }

  Stream<List<PetModel>> _paidPetStream(String uid) {
    late final StreamController<List<PetModel>> controller;
    StreamSubscription<List<PetModel>>? cloudSub;
    StreamSubscription<List<PetModel>>? localSub;
    Future<void>? localCancellation;

    void startLocalFallback() {
      if (localSub != null) return;
      _syncManager.isCloudActive.value = false;
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
        _syncManager.isCloudActive.value = true;
        cloudSub = _remoteDataSource
            .watchPetsByOwner(uid)
            .listen(
              (snapshot) async {
                try {
                  await _syncManager.applyCloudSnapshot(uid, snapshot);
                  await _syncManager.syncPendingOperations(uid);
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
                  _syncManager.isCloudActive.value = true;
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
