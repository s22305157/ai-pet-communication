import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ai_pet_communication/core/session/current_session.dart';
import 'package:ai_pet_communication/core/errors/service_failure.dart';
import 'package:ai_pet_communication/features/chat/application/chat_controller.dart';
import 'package:ai_pet_communication/features/chat/application/communication_input_controller.dart';
import 'package:ai_pet_communication/features/chat/domain/communication_photo.dart';
import 'package:ai_pet_communication/features/chat/domain/communication_photo_repository.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/models/user_model.dart';

class Session extends Mock implements CurrentSession {}

class Chat extends Mock implements ChatController {}

class Photos implements CommunicationPhotoRepository {
  final uploaded = Completer<List<String>>();
  final removed = <String>[];
  int uploads = 0;
  @override
  Future<List<CommunicationPhoto>> pick({int maxPhotos = 3}) async => [
    CommunicationPhoto.fromBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII=',
      ),
    ),
  ];
  @override
  Future<List<String>> upload(
    List<CommunicationPhoto> photos,
    String uid,
    String requestId,
  ) {
    uploads++;
    return uploaded.future;
  }

  @override
  Future<void> remove(List<String> paths) async {
    removed.addAll(paths);
  }
}

void main() {
  late Session session;
  late Photos photos;
  late CommunicationInputController controller;
  var uid = 'a';
  final pet = PetModel(
    petId: 'pet',
    ownerId: 'a',
    name: '貓',
    species: '貓',
    breed: '',
    gender: '',
    birthday: '',
    personality: '',
    avatarUrl: '',
  );
  setUp(() {
    uid = 'a';
    session = Session();
    photos = Photos();
    when(() => session.getUserData()).thenAnswer(
      (_) async => UserModel(
        uid: uid,
        email: '',
        displayName: '',
        subscriptionVerified: true,
        membershipEntitlements: {'plus': DateTime(2100)},
      ),
    );
    controller = CommunicationInputController(
      session: session,
      chat: Chat(),
      photos: photos,
      releaseCredit: (_) async {},
    );
  });
  tearDown(() => controller.dispose());

  test(
    'account switch during upload cleans photos and never sends the old consultation',
    () async {
      await controller.loadPhotoAccess();
      await controller.pickPhotos();
      final pending = controller.submit(
        pet: pet,
        story: '吃飯',
        questions: ['好嗎'],
      );
      await Future<void>.delayed(Duration.zero);
      uid = 'b';
      photos.uploaded.complete(['old-account/photo']);
      await expectLater(
        pending,
        throwsA(
          isA<ServiceFailure>().having(
            (e) => e.kind,
            'kind',
            FailureKind.sessionChanged,
          ),
        ),
      );
      expect(photos.removed, ['old-account/photo']);
      expect(controller.busy, isFalse);
    },
  );

  test(
    'repeated submit during an upload does not create another upload',
    () async {
      await controller.loadPhotoAccess();
      await controller.pickPhotos();
      final pending = controller.submit(
        pet: pet,
        story: '吃飯',
        questions: ['好嗎'],
      );
      expect(
        await controller.submit(pet: pet, story: '吃飯', questions: ['好嗎']),
        isNull,
      );
      await Future<void>.delayed(Duration.zero);
      uid = 'b';
      photos.uploaded.complete(['photo']);
      await expectLater(pending, throwsA(isA<ServiceFailure>()));
      expect(photos.uploads, 1);
    },
  );

  test(
    'ambiguous reservation release can retry, successful release happens once',
    () async {
      var attempts = 0;
      final flow = CommunicationInputController(
        session: session,
        chat: Chat(),
        photos: photos,
        reservationId: 'reservation',
        releaseCredit: (_) async {
          if (++attempts == 1) throw StateError('offline');
        },
      );
      await expectLater(flow.releaseReservation(), throwsStateError);
      await flow.releaseReservation();
      await flow.releaseReservation();
      expect(attempts, 2);
      flow.dispose();
    },
  );
}
