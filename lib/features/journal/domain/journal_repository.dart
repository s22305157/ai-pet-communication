import 'dart:typed_data';

typedef JournalPetNames = List<String> Function(String uid);

abstract interface class JournalRepository {
  String get uid;
  bool get isCurrentSession;
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]);
  Future<String> upload(String petId, Uint8List bytes, String contentType);
  Future<Uint8List> image(String mediaId);
}
