import 'communication_photo.dart';

abstract class CommunicationPhotoRepository {
  Future<List<CommunicationPhoto>> pick({int maxPhotos = 3});

  Future<List<String>> upload(
    List<CommunicationPhoto> photos,
    String uid,
    String requestId,
  );

  Future<void> remove(List<String> paths);
}
