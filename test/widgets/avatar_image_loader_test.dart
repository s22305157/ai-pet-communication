import 'dart:async';
import 'package:ai_pet_communication/widgets/avatar_image_loader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test(
    'empty URL clears bytes and invalidates a slow earlier request',
    () async {
      final slow = Completer<http.Response>();
      final loader = AvatarImageLoader(fetch: (_) => slow.future);
      final pending = loader.load('https://example.test/old');
      await loader.load('');
      slow.complete(http.Response('old', 200));
      await pending;
      expect(loader.bytes, isNull);
      expect(loader.loading, false);
      loader.dispose();
    },
  );

  test('older response cannot replace the latest image', () async {
    final old = Completer<http.Response>();
    final loader = AvatarImageLoader(
      fetch: (uri) => uri.path == '/old'
          ? old.future
          : Future.value(http.Response('new', 200)),
    );
    final pending = loader.load('https://example.test/old');
    await loader.load('https://example.test/new');
    old.complete(http.Response('old', 200));
    await pending;
    expect(String.fromCharCodes(loader.bytes!), 'new');
    await loader.load('');
    expect(loader.bytes, isNull);
    loader.dispose();
  });

  test('dispose during request does not notify listeners', () async {
    final response = Completer<http.Response>();
    final loader = AvatarImageLoader(fetch: (_) => response.future);
    final pending = loader.load('https://example.test/image');
    loader.dispose();
    response.complete(http.Response('image', 200));
    await pending;
  });
}
