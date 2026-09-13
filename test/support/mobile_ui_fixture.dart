import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ai_pet_communication/app/injection.dart';
import 'package:ai_pet_communication/app/theme.dart';
import 'package:ai_pet_communication/features/auth/application/auth_service.dart';
import 'package:ai_pet_communication/features/chat/application/chat_controller.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_response_model.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_safe_response_model.dart';
import 'package:ai_pet_communication/features/chat/domain/communication_photo.dart';
import 'package:ai_pet_communication/features/chat/domain/communication_photo_repository.dart';
import 'package:ai_pet_communication/features/pet/application/pet_service.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/features/onboarding/application/onboarding_service.dart';
import 'package:ai_pet_communication/models/user_model.dart';
import 'package:ai_pet_communication/services/ad_service.dart';
import 'package:ai_pet_communication/services/credit_service.dart';
import 'package:ai_pet_communication/services/membership_action_handler.dart';
import 'package:ai_pet_communication/features/readings/domain/readings_repository.dart';
import 'package:ai_pet_communication/features/readings/application/reading_service.dart';

class UiAuth extends Mock implements AuthService {}

class UiPets extends Mock implements PetService {}

class UiChat extends Mock implements ChatController {}

class UiAds extends Mock implements AdService {}

class UiCredit extends Mock implements CreditService {}

class UiMembership extends Mock implements MembershipActionHandler {}

class UiOnboarding extends Mock implements OnboardingService {}

class UiReadings extends Mock implements ReadingsRepository {}

class UiPhotos implements CommunicationPhotoRepository {
  List<CommunicationPhoto> selection = [];
  Object? pickError;
  @override
  Future<List<CommunicationPhoto>> pick({int maxPhotos = 3}) async {
    if (pickError != null) throw pickError!;
    return selection;
  }

  @override
  Future<List<String>> upload(
    List<CommunicationPhoto> photos,
    String uid,
    String requestId,
  ) async => [];
  @override
  Future<void> remove(List<String> paths) async {}
}

class MobileUiFixture {
  final auth = UiAuth();
  final pets = UiPets();
  final chat = UiChat();
  final ads = UiAds();
  final membership = UiMembership();
  final onboarding = UiOnboarding();
  final photos = UiPhotos();
  final readings = UiReadings();
  final syncing = ValueNotifier(false);
  final cloud = ValueNotifier(true);
  late UserModel user;
  static final pet = PetModel(
    petId: 'demo-pet',
    ownerId: 'demo-user',
    name: '小米',
    species: '狗',
    breed: '米克斯',
    gender: '母',
    birthday: '2022-01-01',
    personality: '親人',
    avatarUrl: '',
  );
  static final response = AiResponseModel.fromMap({
    'petVoice': [
      {'question': '散步時怎麼陪你比較好？', 'answer': '讓我慢慢聞聞路邊的味道，也陪我找個安靜的地方休息。'},
    ],
    'knowledgeStation': {
      'title': '一起練習自在散步',
      'content': '選擇安靜的路線，觀察毛孩的步調。需要休息時，就停下來陪伴牠。',
    },
    'summary': '放慢步調，留意毛孩的反應，讓散步成為舒服的相處時間。',
  });
  static final safeResponse = AiSafeResponseModel.fromMap({
    'pet_voice': {'text': '請陪我一起尋求協助。'},
    'safety_alert': {'has_red_flags': true, 'message': '請立即聯絡獸醫，告知目前觀察到的異常。'},
    'next_steps': ['先聯絡附近的動物醫院。'],
    'knowledge_tips': ['整理異常開始的時間與變化。'],
  });

  Future<void> install({
    String tier = 'plus',
    String name = '小米的家人',
    int points = 120,
    List<PetModel>? items,
  }) async {
    await getIt.reset();
    user = UserModel(
      uid: 'demo-user',
      email: '',
      displayName: name,
      points: points,
      membershipTier: tier,
      subscriptionVerified: tier != 'free',
      membershipEntitlements: tier == 'free' ? {} : {tier: DateTime(2100)},
    );
    when(() => auth.getUserData()).thenAnswer((_) async => user);
    when(() => auth.getUserStream()).thenAnswer((_) => Stream.value(user));
    when(() => pets.isSyncing).thenReturn(syncing);
    when(() => pets.isCloudActive).thenReturn(cloud);
    when(
      () => pets.watchPetsByOwner(any()),
    ).thenAnswer((_) => Stream.value(items ?? [pet]));
    getIt.registerSingleton<AuthService>(auth);
    getIt.registerSingleton<PetService>(pets);
    getIt.registerSingleton<ChatController>(chat);
    getIt.registerSingleton<CommunicationPhotoRepository>(photos);
    getIt.registerSingleton<CreditService>(UiCredit());
    getIt.registerSingleton<AdService>(ads);
    getIt.registerSingleton<MembershipActionHandler>(membership);
    getIt.registerSingleton<OnboardingService>(onboarding);
    when(
      () => readings.watchReadingsByPetId(any()),
    ).thenAnswer((_) => Stream.value([]));
    getIt.registerSingleton<ReadingsRepository>(readings);
    getIt.registerSingleton<ReadingService>(ReadingService(readings));
  }

  Widget app(Widget page, {double scale = 1}) => MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: page,
  );
  Future<void> dispose() async {
    await getIt.reset();
    syncing.dispose();
    cloud.dispose();
  }
}
