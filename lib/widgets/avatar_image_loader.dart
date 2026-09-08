import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Owns one image request generation. Empty URLs and failures clear old bytes.
class AvatarImageLoader extends ChangeNotifier {
  AvatarImageLoader({Future<http.Response> Function(Uri)? fetch})
    : _fetch = fetch ?? http.get;
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
      final response = await _fetch(Uri.parse(url));
      if (_disposed || generation != _generation) return;
      if (response.statusCode == 200) bytes = response.bodyBytes;
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
