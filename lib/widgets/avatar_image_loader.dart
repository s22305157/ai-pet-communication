import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Owns one image request generation. Empty URLs and failures clear old bytes.
class AvatarImageLoader extends ChangeNotifier {
  AvatarImageLoader({Future<http.Response> Function(Uri)? fetch})
    : _fetch = fetch ?? _download;
  static const maxBytes = 10 * 1024 * 1024;
  static Future<http.Response> _download(Uri uri) async {
    if (uri.scheme == 'data') {
      if (uri.toString().length > maxBytes * 4 / 3 + 256) {
        throw StateError('Image exceeds size limit');
      }
      final bytes = uri.data!.contentAsBytes();
      if (bytes.length > maxBytes) throw StateError('Image exceeds size limit');
      return http.Response.bytes(bytes, 200);
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      throw ArgumentError('Invalid image URL');
    }
    final client = http.Client();
    try {
      return await (() async {
        final response = await client.send(http.Request('GET', uri));
        if ((response.contentLength ?? 0) > maxBytes) {
          throw StateError('Image exceeds size limit');
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > maxBytes) {
            throw StateError('Image exceeds size limit');
          }
          bytes.add(chunk);
        }
        return http.Response.bytes(bytes.takeBytes(), response.statusCode);
      })().timeout(const Duration(seconds: 10));
    } finally {
      client.close();
    }
  }

  final Future<http.Response> Function(Uri) _fetch;
  Uint8List? bytes;
  bool loading = false;
  int _generation = 0;
  bool _disposed = false;

  Future<void> load(String url) async {
    if (_disposed) return;
    final generation = ++_generation;
    bytes = null;
    loading = url.isNotEmpty;
    notifyListeners();
    if (url.isEmpty) return;
    try {
      final response = await _fetch(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 10));
      if (_disposed || generation != _generation) return;
      if (response.statusCode == 200 && response.bodyBytes.length <= maxBytes) {
        bytes = response.bodyBytes;
      }
    } catch (_) {
      // Render the caller's placeholder on malformed URLs or network failures.
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    super.dispose();
  }
}
