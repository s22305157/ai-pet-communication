import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../domain/journal_repository.dart';
import '../data/journal_download.dart';

class JournalImage extends StatefulWidget {
  final JournalRepository repository;
  final String mediaId;
  const JournalImage({
    super.key,
    required this.repository,
    required this.mediaId,
  });
  @override
  State<JournalImage> createState() => _JournalImageState();
}

class _JournalImageState extends State<JournalImage> {
  late Future<Uint8List> _image;
  @override
  void initState() {
    super.initState();
    _image = widget.repository.image(widget.mediaId);
  }

  @override
  void didUpdateWidget(covariant JournalImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaId != widget.mediaId ||
        oldWidget.repository != widget.repository) {
      _image = widget.repository.image(widget.mediaId);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 110,
    height: 110,
    child: FutureBuilder<Uint8List>(
      future: _image,
      builder: (context, snapshot) {
        if (!widget.repository.isCurrentSession) return const SizedBox.shrink();
        if (snapshot.hasError) return const Center(child: Text('照片無法載入'));
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              content: Image.memory(snapshot.data!, fit: BoxFit.contain),
              actions: [
                TextButton(
                  onPressed: () async {
                    if (!widget.repository.isCurrentSession) return;
                    try {
                      await downloadJournalFile(
                        snapshot.data!,
                        '${widget.mediaId}.jpg',
                        'image/jpeg',
                      );
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('請使用網站下載照片')),
                        );
                      }
                    }
                  },
                  child: const Text('下載照片'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('關閉'),
                ),
              ],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
              excludeFromSemantics: false,
              semanticLabel: '私人日記照片，點選放大或下載',
            ),
          ),
        );
      },
    ),
  );
}
