import 'dart:typed_data';

class CommunicationPhoto {
  static const maxBytes = 10 * 1024 * 1024;
  final Uint8List bytes;
  final String contentType;

  const CommunicationPhoto(this.bytes, this.contentType);

  factory CommunicationPhoto.fromBytes(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('照片不可為空，每張上限 10 MB');
    }
    final String type;
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      type = 'image/jpeg';
    } else if (bytes.length >= 8 &&
        bytes.take(8).join(',') == '137,80,78,71,13,10,26,10') {
      type = 'image/png';
    } else {
      throw const FormatException('請選擇 JPG 或 PNG 照片');
    }
    return CommunicationPhoto(bytes, type);
  }
}
