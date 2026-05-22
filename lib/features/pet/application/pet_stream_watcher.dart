import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/models/pet_model.dart';
import '../data/local_pet_service.dart';
import '../data/sources/pet_remote_data_source.dart';
import '../../../services/auth_service.dart';
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
  })  : _remoteDataSource = remoteDataSource,
        _localService = localService,
        _authService = authService,
        _syncManager = syncManager;

  Stream<List<PetModel>> watchPetsByOwner(String uid) async* {
    final user = await _authService.getUserData();
    
    if (user == null) {
      yield [];
      return;
    }

    if (user.membershipType == 'free') {
      yield* _localService.watchPets();
    } else {
      // 付費帳戶 (Plus/Pro)：先嘗試雲端，失敗則降級本地
      _syncManager.migrateIfNeeded(uid);
      
      final controller = StreamController<List<PetModel>>();
      StreamSubscription? cloudSub;
      StreamSubscription? localSub;

      void startLocalFallback() {
        if (localSub != null) return;
        _syncManager.isCloudActive.value = false;
        localSub = _localService.watchPets().listen(
          (data) {
            if (!controller.isClosed) controller.add(data);
          },
          onError: (e) {
            if (!controller.isClosed) controller.addError(e);
          },
        );
      }

      controller.onListen = () {
        _syncManager.isCloudActive.value = true;
        cloudSub = _remoteDataSource.watchPetsByOwner(uid).listen(
          (snapshot) {
            _syncManager.isCloudActive.value = true;
            if (!controller.isClosed) {
              controller.add(snapshot);
            }
          },
          onError: (error) {
            debugPrint('雲端監聽錯誤: $error。啟動本地降級串流。');
            startLocalFallback();
          },
          cancelOnError: false,
        );
      };

      controller.onCancel = () {
        cloudSub?.cancel();
        localSub?.cancel();
        controller.close();
      };

      yield* controller.stream;
    }
  }
}
