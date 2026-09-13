import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:ai_pet_communication/core/errors/service_failure.dart';
import 'package:ai_pet_communication/core/session/current_session.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import '../domain/ai_request_model.dart';
import '../domain/communication_photo.dart';
import '../domain/communication_photo_repository.dart';
import '../domain/media_payload.dart';
import 'chat_controller.dart';

/// Owns one consultation's uploads, account checks and legacy reservation cleanup.
class CommunicationInputController extends ChangeNotifier {
  final CurrentSession session;
  final ChatController chat;
  final CommunicationPhotoRepository photos;
  final Future<void> Function(String) releaseCredit;
  final String? reservationId;
  final DateTime Function() clock;
  final List<CommunicationPhoto> _selected = [];
  List<CommunicationPhoto> get selected => List.unmodifiable(_selected);
  bool busy = false;
  bool picking = false;
  bool canUsePhotos = false;
  bool _closed = false, _creditFinalized = false;
  String? _photoOwner;
  Future<void>? _releaseFuture;

  CommunicationInputController({
    required this.session,
    required this.chat,
    required this.photos,
    required this.releaseCredit,
    this.reservationId,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  void _notify() {
    if (!_closed) notifyListeners();
  }

  Future<void> loadPhotoAccess() async {
    try {
      final user = await session.getUserData();
      if (_closed) return;
      canUsePhotos = user != null && user.membershipTier != 'free';
      _photoOwner = user?.uid;
      _notify();
    } catch (_) {
      // Text consultation remains available when membership cannot be loaded.
    }
  }

  Future<void> pickPhotos() async {
    if (_closed || busy || picking || !canUsePhotos) return;
    picking = true;
    _notify();
    try {
      final values = await photos.pick(maxPhotos: 3 - _selected.length);
      if (_closed) return;
      if (values.length + _selected.length > 3) {
        throw const FormatException('最多上傳 3 張照片，請重新選擇');
      }
      _selected.addAll(values);
    } finally {
      picking = false;
      _notify();
    }
  }

  void removePhoto(int index) {
    if (_closed || busy || picking) return;
    _selected.removeAt(index);
    _notify();
  }

  Future<void> _checkOwner(String owner) async {
    final current = await session.getUserData();
    if (_closed || current?.uid != owner) {
      throw const ServiceFailure(
        FailureKind.sessionChanged,
        message: '登入帳號已變更',
      );
    }
  }

  Future<CommunicationOutcome?> submit({
    required PetModel pet,
    required String story,
    required List<String> questions,
  }) async {
    if (_closed || busy || picking) return null;
    busy = true;
    _notify();
    var uploaded = <String>[];
    try {
      final user = await session.getUserData();
      if (_closed) return null;
      if (user == null) throw const ServiceFailure(FailureKind.unauthenticated);
      final operationId = reservationId ?? const Uuid().v4();
      if (_selected.isNotEmpty) {
        if (user.uid != _photoOwner || user.membershipTier == 'free') {
          throw const ServiceFailure(
            FailureKind.permissionDenied,
            message: '照片分析需有效 Plus／Pro 會員，請確認帳號或移除照片',
          );
        }
        uploaded = await photos.upload(
          List.of(_selected),
          user.uid,
          operationId,
        );
      }
      await _checkOwner(user.uid);
      final birthday = DateTime.tryParse(pet.birthday);
      final now = clock();
      final outcome = await chat.handleCommunicationWithPersistence(
        pet.petId,
        AiRequestModel(
          ownerProfile: const OwnerProfile(
            experienceLevel: '',
            careStyle: '',
            emotionStyle: '',
            dailyRoutine: '',
            mainConcern: '',
          ),
          petProfile: PetProfile(
            name: pet.name,
            species: pet.species,
            breed: pet.breed,
            age: birthday == null || birthday.isAfter(now)
                ? null
                : now.difference(birthday).inDays / 365.25,
            coatColor: pet.color,
            personalityTraits: [pet.personality],
          ),
          story: story.trim(),
          questions: questions,
          inputMode: user.membershipTier,
          media: uploaded.isEmpty ? null : MediaPayload(photos: uploaded),
        ),
        requestId: uploaded.isEmpty ? reservationId : operationId,
      );
      await _checkOwner(user.uid);
      if (outcome.isFallback) {
        throw const ServiceFailure(FailureKind.unavailable);
      }
      _creditFinalized = true;
      return outcome;
    } finally {
      try {
        await photos.remove(uploaded);
      } finally {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> releaseReservation() {
    if (reservationId == null || _creditFinalized) return Future.value();
    return _releaseFuture ??= _release();
  }

  Future<void> _release() async {
    try {
      await releaseCredit(reservationId!);
      _creditFinalized = true;
    } finally {
      if (!_creditFinalized) _releaseFuture = null;
    }
  }

  Future<void> retryPersistence(CommunicationOutcome outcome) =>
      chat.retryPersistence(outcome);

  @override
  void dispose() {
    _closed = true;
    _selected.clear();
    super.dispose();
  }
}
