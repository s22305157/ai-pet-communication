import 'package:ai_pet_communication/features/pet/application/pet_cleanup_repository.dart';
import 'package:ai_pet_communication/app/account_data_cleanup.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:ai_pet_communication/features/auth/application/auth_service.dart';
import 'package:ai_pet_communication/services/subscription_service.dart';
import 'package:ai_pet_communication/services/ad_service.dart';
import 'package:ai_pet_communication/features/pet/data/local_pet_service.dart';
import 'package:ai_pet_communication/features/pet/application/pet_service.dart';
import 'package:ai_pet_communication/features/pet/data/sources/pet_remote_data_source.dart';
import 'package:ai_pet_communication/features/pet/application/pet_sync_manager.dart';
import 'package:ai_pet_communication/features/pet/domain/repositories/pet_repository.dart';
import 'package:ai_pet_communication/features/pet/data/repositories/pet_repository_impl.dart';
import 'package:ai_pet_communication/features/pet/domain/repositories/avatar_upload_repository.dart';
import 'package:ai_pet_communication/features/pet/data/repositories/avatar_upload_repository_impl.dart';
import 'package:ai_pet_communication/features/pet/application/pet_stream_watcher.dart';
import 'package:ai_pet_communication/features/onboarding/application/onboarding_service.dart';
import 'package:ai_pet_communication/features/chat/data/chat_service.dart';
import 'package:ai_pet_communication/features/readings/domain/readings_repository.dart';
import 'package:ai_pet_communication/features/readings/data/firestore_readings_repository.dart';
import 'package:ai_pet_communication/features/readings/data/local_readings_repository.dart';
import 'package:ai_pet_communication/features/readings/data/account_readings_repository.dart';
import 'package:ai_pet_communication/features/readings/application/reading_service.dart';
import 'package:ai_pet_communication/features/chat/application/chat_controller.dart';
import 'package:ai_pet_communication/features/knowledge/application/knowledge_retrieval_service.dart';
import 'package:ai_pet_communication/services/membership_action_handler.dart';
import 'package:ai_pet_communication/services/credit_service.dart';

final getIt = GetIt.instance;

void setupDependencies() {
  // ── 基礎核心與外部套件 ──────────────────
  getIt.registerLazySingleton<FirebaseFirestore>(
    () => FirebaseFirestore.instance,
  );
  getIt.registerLazySingleton<FirebaseStorage>(() => FirebaseStorage.instance);
  getIt.registerLazySingleton<FirebaseFunctions>(
    () => FirebaseFunctions.instance,
  );

  // ── 基礎系統服務 ──────────────────
  getIt.registerLazySingleton<LocalPetService>(() => LocalPetService());
  getIt.registerLazySingleton<LocalReadingsRepository>(
    () => LocalReadingsRepository(),
  );
  getIt.registerLazySingleton<AuthService>(
    () => AuthService(
      cleanup: AccountDataCleanup([
        getIt<LocalPetService>(),
        getIt<LocalReadingsRepository>(),
      ]),
    ),
    dispose: (service) => service.dispose(),
  );
  getIt.registerLazySingleton<SubscriptionService>(() => SubscriptionService());
  getIt.registerLazySingleton<AdService>(() => AdService());
  getIt.registerLazySingleton<CreditService>(
    () => CreditService(functions: getIt<FirebaseFunctions>()),
  );
  getIt.registerLazySingleton<OnboardingService>(() => OnboardingService());
  getIt.registerLazySingleton<MembershipActionHandler>(
    () => MembershipActionHandler(
      getIt<AuthService>(),
      getIt<AdService>(),
      getIt<CreditService>(),
    ),
  );

  getIt.registerLazySingleton<PetRemoteDataSource>(
    () => PetRemoteDataSource(
      firestore: getIt<FirebaseFirestore>(),
      storage: getIt<FirebaseStorage>(),
      functions: getIt<FirebaseFunctions>(),
    ),
  );

  getIt.registerLazySingleton<PetSyncManager>(
    () => PetSyncManager(
      localService: getIt<LocalPetService>(),
      remoteDataSource: getIt<PetRemoteDataSource>(),
    ),
    dispose: (manager) => manager.dispose(),
  );

  getIt.registerLazySingleton<PetRepository>(
    () => PetCleanupRepository(
      session: getIt<AuthService>(),
      readings: getIt<LocalReadingsRepository>(),
      pets: PetRepositoryImpl(
        remoteDataSource: getIt<PetRemoteDataSource>(),
        localService: getIt<LocalPetService>(),
        authService: getIt<AuthService>(),
      ),
    ),
  );

  getIt.registerLazySingleton<AvatarUploadRepository>(
    () => AvatarUploadRepositoryImpl(
      remoteDataSource: getIt<PetRemoteDataSource>(),
    ),
  );

  getIt.registerLazySingleton<PetStreamWatcher>(
    () => PetStreamWatcher(
      remoteDataSource: getIt<PetRemoteDataSource>(),
      localService: getIt<LocalPetService>(),
      authService: getIt<AuthService>(),
      syncManager: getIt<PetSyncManager>(),
    ),
  );

  getIt.registerLazySingleton<PetService>(
    () => PetService(
      repository: getIt<PetRepository>(),
      avatarUploadRepository: getIt<AvatarUploadRepository>(),
      streamWatcher: getIt<PetStreamWatcher>(),
      syncManager: getIt<PetSyncManager>(),
    ),
  );

  // ── 寵物 AI 聊天溝通功能模組 ──────────────────
  getIt.registerLazySingleton<ChatService>(() => ChatService());
  getIt.registerLazySingleton<KnowledgeRetrievalService>(
    () => KnowledgeRetrievalService(functions: getIt<FirebaseFunctions>()),
  );

  getIt.registerLazySingleton<ReadingsRepository>(
    () => AccountReadingsRepository(
      authService: getIt<AuthService>(),
      localPets: getIt<LocalPetService>(),
      localReadings: getIt<LocalReadingsRepository>(),
      cloudReadings: FirestoreReadingsRepository(getIt<FirebaseFirestore>()),
    ),
  );

  getIt.registerLazySingleton<ReadingService>(
    () => ReadingService(getIt<ReadingsRepository>()),
  );

  // Controller 使用 Factory，使每次調用皆建立全新狀態
  getIt.registerFactory<ChatController>(
    () => ChatController(
      getIt<ChatService>(),
      getIt<ReadingService>(),
      getIt<KnowledgeRetrievalService>(),
    ),
  );
}
