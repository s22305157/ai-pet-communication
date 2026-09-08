import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:ai_pet_communication/features/pet/data/repositories/pet_repository_impl.dart';
import 'package:ai_pet_communication/features/pet/data/repositories/avatar_upload_repository_impl.dart';
import 'package:ai_pet_communication/features/pet/application/pet_stream_watcher.dart';
import 'package:ai_pet_communication/features/pet/data/local_pet_service.dart';
import 'package:ai_pet_communication/features/pet/data/sources/pet_remote_data_source.dart';
import 'package:ai_pet_communication/features/pet/application/pet_sync_manager.dart';
import 'package:ai_pet_communication/features/auth/application/auth_service.dart';
import 'package:ai_pet_communication/features/pet/application/pet_service.dart';

PetService buildPetService({
  required FirebaseFirestore firestore,
  required FirebaseStorage storage,
  required LocalPetService localService,
  required AuthService authService,
}) {
  final remote = PetRemoteDataSource(firestore: firestore, storage: storage);
  final sync = PetSyncManager(
    localService: localService,
    remoteDataSource: remote,
  );
  return PetService(
    repository: PetRepositoryImpl(
      remoteDataSource: remote,
      localService: localService,
      authService: authService,
    ),
    avatarUploadRepository: AvatarUploadRepositoryImpl(
      remoteDataSource: remote,
    ),
    streamWatcher: PetStreamWatcher(
      remoteDataSource: remote,
      localService: localService,
      authService: authService,
      syncManager: sync,
    ),
    syncManager: sync,
  );
}
