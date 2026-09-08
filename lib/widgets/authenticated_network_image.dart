import 'package:flutter/material.dart';

import '../utils/web_helper.dart';

class AuthenticatedNetworkImage extends StatefulWidget {
  final String url;
  final BoxFit? fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  final Widget authLoadingPlaceholder;

  const AuthenticatedNetworkImage({
    super.key,
    required this.url,
    required this.authLoadingPlaceholder,
    this.fit,
    this.errorBuilder,
    this.loadingBuilder,
  });

  @override
  State<AuthenticatedNetworkImage> createState() =>
      _AuthenticatedNetworkImageState();
}

class _AuthenticatedNetworkImageState extends State<AuthenticatedNetworkImage> {
  Future<Map<String, String>?>? _headers;

  @override
  void initState() {
    super.initState();
    _prepareRequest();
  }

  @override
  void didUpdateWidget(AuthenticatedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _prepareRequest();
  }

  void _prepareRequest() {
    _headers = WebHelper.shouldProxy(widget.url)
        ? WebHelper.getProxyAuthHeaders()
        : null;
  }

  Widget _image([Map<String, String>? headers]) {
    return Image.network(
      WebHelper.getWebSafeUrl(widget.url),
      headers: headers,
      fit: widget.fit,
      errorBuilder: widget.errorBuilder,
      loadingBuilder: widget.loadingBuilder,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_headers == null) return _image();

    return FutureBuilder<Map<String, String>?>(
      future: _headers,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.authLoadingPlaceholder;
        }
        if (snapshot.hasError || snapshot.data == null) {
          return widget.errorBuilder?.call(
                context,
                snapshot.error ?? StateError('Authentication required'),
                snapshot.stackTrace,
              ) ??
              const SizedBox.shrink();
        }
        return _image(snapshot.data);
      },
    );
  }
}
