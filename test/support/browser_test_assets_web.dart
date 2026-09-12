import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
// Google Fonts exposes this injection point specifically for tests.
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as fonts;

const _assetBase = String.fromEnvironment('PAWLINK_TEST_ASSET_BASE');
final _assets = <String, ByteData>{};

// Match Flutter's standard test font rather than fetching remote font files.
class _TestFontManifest implements AssetManifest {
  @override
  List<String> listAssets() => [
    for (final family in ['Outfit', 'Montserrat'])
      for (final weight in [
        'Thin',
        'ExtraLight',
        'Light',
        'Regular',
        'Medium',
        'SemiBold',
        'Bold',
        'ExtraBold',
        'Black',
      ])
        for (final style in ['', 'Italic'])
          '__test_fonts/$family-$weight$style.ttf',
  ];

  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

Future<ByteData> _load(String key) async {
  if (_assets[key] case final cached?) return cached;
  final uri = Uri.parse(_assetBase).resolveUri(Uri(path: key));
  final response = await http.get(uri);
  if (response.statusCode != 200) {
    throw StateError('Test asset unavailable: $key (${response.statusCode})');
  }
  return _assets[key] = ByteData.sublistView(response.bodyBytes);
}

Future<void> installBrowserTestAssets() async {
  if (_assetBase.isEmpty) return;
  // setUp runs outside the widget's fake clock, so the manifest can use HTTP.
  await _load('AssetManifest.bin.json');
  final testFont = await _load('__test_fonts/Ahem.ttf');
  fonts.assetManifest = _TestFontManifest();
  for (final key in fonts.assetManifest!.listAssets()) {
    _assets[key] = testFont;
  }
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) {
        if (message == null) return Future.value(null);
        final key = utf8.decode(
          message.buffer.asUint8List(
            message.offsetInBytes,
            message.lengthInBytes,
          ),
        );
        return _load(key);
      });
}
