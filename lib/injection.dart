import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'services/auth_service.dart';
import 'services/subscription_service.dart';
import 'services/ad_service.dart';
import 'features/pet/data/local_pet_service.dart';
import 'features/pet/application/pet_service.dart';
import 'services/onboarding_service.dart';
import 'features/chat/data/chat_service.dart';
import 'features/readings/data/readings_repository.dart';
import 'features/readings/data/firestore_readings_repository.dart';
import 'features/readings/application/reading_service.dart';
import 'features/chat/application/chat_controller.dart';

final getIt = GetIt.instance;

void setupDependencies() {
  // ── 基礎核心與外部套件 ──────────────────
  getIt.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
  getIt.registerLazySingleton<FirebaseStorage>(() => FirebaseStorage.instance);

  // ── 基礎系統服務 ──────────────────
  getIt.registerLazySingleton<LocalPetService>(() => LocalPetService());
  getIt.registerLazySingleton<AuthService>(() => AuthService());
  getIt.registerLazySingleton<SubscriptionService>(() => SubscriptionService());
  getIt.registerLazySingleton<AdService>(() => AdService());
  getIt.registerLazySingleton<OnboardingService>(() => OnboardingService());

  getIt.registerLazySingleton<PetService>(() => PetService(
    firestore: getIt<FirebaseFirestore>(),
    storage: getIt<FirebaseStorage>(),
    localService: getIt<LocalPetService>(),
    authService: getIt<AuthService>(),
  ));

  // ── 寵物 AI 聊天溝通功能模組 ──────────────────
  getIt.registerLazySingleton<ChatService>(() => ChatService());
  
  getIt.registerLazySingleton<ReadingsRepository>(
    () => FirestoreReadingsRepository(getIt<FirebaseFirestore>())
  );
  
  getIt.registerLazySingleton<ReadingService>(
    () => ReadingService(getIt<ReadingsRepository>())
  );

  // Controller 使用 Factory，使每次調用皆建立全新狀態
  getIt.registerFactory<ChatController>(
    () => ChatController(getIt<ChatService>(), getIt<ReadingService>())
  );
}
