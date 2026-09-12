import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../features/pilot/domain/pilot_repository.dart';
import '../features/pilot/domain/pilot_request.dart';

class CommunityImage extends StatefulWidget {
  final PilotRepository repository;
  final String postId, mediaId;
  final String? reportId;
  const CommunityImage({
    super.key,
    required this.repository,
    required this.postId,
    required this.mediaId,
    this.reportId,
  });
  @override
  State<CommunityImage> createState() => _CommunityImageState();
}

class _CommunityImageState extends State<CommunityImage> {
  late final _image = widget.repository.execute(
    GetCommunityImage(
      postId: widget.postId,
      mediaId: widget.mediaId,
      reportId: widget.reportId,
    ),
  );
  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
    stream: widget.repository.sessionChanges,
    initialData: widget.repository.isCurrentSession,
    builder: (context, session) => session.data != true
        ? const SizedBox.shrink()
        : FutureBuilder<Uint8List>(
            future: _image,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const SizedBox(
                  width: 130,
                  height: 90,
                  child: Center(child: Text('圖片已移除或無法讀取')),
                );
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  width: 130,
                  height: 90,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return Image.memory(
                snapshot.data!,
                width: 180,
                height: 150,
                fit: BoxFit.contain,
                gaplessPlayback: false,
              );
            },
          ),
  );
}
