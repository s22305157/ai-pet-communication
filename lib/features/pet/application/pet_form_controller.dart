import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_write_result.dart';
import 'package:ai_pet_communication/features/pet/application/pet_service.dart';

class PetFormController {
  PetFormController({
    required this.service,
    required this.currentUid,
    Future<Uint8List?> Function()? pickImage,
  }) : _pickImage = pickImage ?? _pick;
  final PetService service;
  final Future<String?> Function() currentUid;
  final Future<Uint8List?> Function() _pickImage;

  static Future<Uint8List?> _pick() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    return file?.readAsBytes();
  }

  Future<({Uint8List bytes, String url})?> pickAndUpload() async {
    final uid = await currentUid();
    if (uid == null) throw const PetWriteFailure('請先登入');
    final bytes = await _pickImage();
    if (bytes == null) return null;
    if (await currentUid() != uid) throw const PetWriteFailure('帳號已變更，請重新開啟表單');
    final url = await service.uploadPetAvatar(uid, const Uuid().v4(), bytes);
    if (await currentUid() != uid) throw const PetWriteFailure('帳號已變更，請重新開啟表單');
    return (bytes: bytes, url: url);
  }

  Future<PetWriteResult> save(PetModel draft, {required bool isNew}) async {
    if (await currentUid() != draft.ownerId) {
      throw const PetWriteFailure('帳號已變更，請重新開啟表單');
    }
    return isNew
        ? service.createPet(draft)
        : service.updatePet(draft.petId, draft);
  }

  static String message(PetWriteResult result) => switch (result) {
    PetWriteResult.saved => '儲存成功！',
    PetWriteResult.pendingSync => '已儲存在此裝置，等待同步',
    PetWriteResult.conflict => '雲端資料已更新，尚未套用你的修改；草稿已保留',
  };
}
