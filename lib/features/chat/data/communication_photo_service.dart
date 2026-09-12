import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../domain/communication_photo.dart';
import '../domain/communication_photo_repository.dart';

class CommunicationPhotoService implements CommunicationPhotoRepository {
  final ImagePicker _picker;

  CommunicationPhotoService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  @override
  Future<List<CommunicationPhoto>> pick({int maxPhotos = 3}) async {
    final files = await _picker.pickMultiImage();
    if (files.length > maxPhotos || files.length > 3) {
      throw const FormatException('最多上傳 3 張照片，請重新選擇');
    }
    final photos = <CommunicationPhoto>[];
    for (final file in files) {
      if (await file.length() > CommunicationPhoto.maxBytes) {
        throw const FormatException('每張照片上限 10 MB');
      }
      photos.add(CommunicationPhoto.fromBytes(await file.readAsBytes()));
    }
    return photos;
  }

  @override
  Future<List<String>> upload(
    List<CommunicationPhoto> photos,
    String uid,
    String requestId,
  ) async {
    if (photos.length > 3) throw const FormatException('最多上傳 3 張照片');
    final paths = <String>[];
    try {
      for (var i = 0; i < photos.length; i++) {
        if (FirebaseAuth.instance.currentUser?.uid != uid) {
          throw StateError('登入帳號已變更');
        }
        final photo = photos[i];
        if (photo.bytes.isEmpty ||
            photo.bytes.length > CommunicationPhoto.maxBytes) {
          throw const FormatException('每張照片上限 10 MB');
        }
        final path = 'communicationPhotos/$uid/$requestId/$i';
        paths.add(path);
        await FirebaseStorage.instance
            .ref(path)
            .putData(
              photo.bytes,
              SettableMetadata(contentType: photo.contentType),
            );
      }
      if (FirebaseAuth.instance.currentUser?.uid != uid) {
        throw StateError('登入帳號已變更');
      }
      return paths;
    } catch (_) {
      await remove(paths);
      rethrow;
    }
  }

  @override
  Future<void> remove(List<String> paths) async {
    for (final path in paths) {
      try {
        await FirebaseStorage.instance.ref(path).delete();
      } catch (_) {
        // Best effort: session changes or connectivity may prevent cleanup.
      }
    }
  }
}
