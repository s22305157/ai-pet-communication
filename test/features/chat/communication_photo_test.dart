import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ai_pet_communication/features/chat/data/communication_photo_service.dart';
import 'package:ai_pet_communication/features/chat/domain/communication_photo.dart';

class MockImagePicker extends Mock implements ImagePicker {}

class MockPhotoFile extends Mock implements XFile {}

void main() {
  late MockImagePicker picker;
  late CommunicationPhotoService service;

  setUp(() {
    picker = MockImagePicker();
    service = CommunicationPhotoService(picker: picker);
  });

  test('accepts exact 10 MB and rejects larger files before upload', () async {
    final bytes = Uint8List(CommunicationPhoto.maxBytes)
      ..setAll(0, [255, 216, 255]);
    when(
      () => picker.pickMultiImage(),
    ).thenAnswer((_) async => [XFile.fromData(bytes, name: 'a.jpg')]);
    expect((await service.pick()).single.contentType, 'image/jpeg');
    when(
      () => picker.pickMultiImage(),
    ).thenAnswer((_) async => [XFile.fromData(Uint8List(bytes.length + 1))]);
    await expectLater(service.pick(), throwsFormatException);
  });
  test('empty or fake images cannot be selected', () async {
    for (final bytes in [
      Uint8List(0),
      Uint8List.fromList([1, 2, 3]),
    ]) {
      when(
        () => picker.pickMultiImage(),
      ).thenAnswer((_) async => [XFile.fromData(bytes, name: 'fake.jpg')]);
      await expectLater(service.pick(), throwsFormatException);
    }
  });

  test('JPEG and PNG signatures override untrusted file metadata', () async {
    final signatures = [
      [255, 216, 255],
      [137, 80, 78, 71, 13, 10, 26, 10],
    ];
    when(() => picker.pickMultiImage()).thenAnswer(
      (_) async => signatures
          .map(
            (bytes) => XFile.fromData(
              Uint8List.fromList(bytes),
              name: 'photo.txt',
              mimeType: 'text/plain',
            ),
          )
          .toList(),
    );
    expect((await service.pick()).map((photo) => photo.contentType), [
      'image/jpeg',
      'image/png',
    ]);
  });

  test('WebP is rejected even with a JPEG or PNG name and MIME type', () async {
    final bytes = Uint8List.fromList([
      ...'RIFF'.codeUnits,
      0,
      0,
      0,
      0,
      ...'WEBP'.codeUnits,
    ]);
    for (final format in ['webp', 'jpeg', 'png']) {
      when(() => picker.pickMultiImage()).thenAnswer(
        (_) async => [
          XFile.fromData(
            bytes,
            name: 'photo.$format',
            mimeType: 'image/$format',
          ),
        ],
      );
      await expectLater(
        service.pick(),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            '請選擇 JPG 或 PNG 照片',
          ),
        ),
      );
    }
  });

  test('more than three files are rejected before any file is read', () async {
    final file = MockPhotoFile();
    when(
      () => picker.pickMultiImage(),
    ).thenAnswer((_) async => [file, file, file, file]);
    await expectLater(service.pick(), throwsFormatException);
    verifyZeroInteractions(file);
  });

  test('selection respects the remaining photo slots before reading', () async {
    final file = MockPhotoFile();
    when(() => picker.pickMultiImage()).thenAnswer((_) async => [file, file]);
    await expectLater(service.pick(maxPhotos: 1), throwsFormatException);
    verifyZeroInteractions(file);
  });

  test('oversized file is rejected before allocating its contents', () async {
    final file = MockPhotoFile();
    when(
      () => file.length(),
    ).thenAnswer((_) async => CommunicationPhoto.maxBytes + 1);
    when(() => picker.pickMultiImage()).thenAnswer((_) async => [file]);
    await expectLater(service.pick(), throwsFormatException);
    verifyNever(() => file.readAsBytes());
  });

  test('cancelling selection returns no photos', () async {
    when(() => picker.pickMultiImage()).thenAnswer((_) async => []);
    expect(await service.pick(), isEmpty);
  });
}
