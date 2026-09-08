import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_pet_communication/widgets/avatar_image_loader.dart';
import 'package:ai_pet_communication/app/theme.dart';

/// 通用的寵物頭像元件
/// - 若有 [avatarUrl]，用 http 抓成 bytes 再以 Image.memory 顯示（繞過 CORS）
/// - 若無 URL 或載入失敗，顯示 [petName] 的首字母作為 placeholder
class PetAvatar extends StatefulWidget {
  final String avatarUrl;
  final String petName;
  final double size;
  final double fontSize;

  const PetAvatar({
    super.key,
    required this.avatarUrl,
    required this.petName,
    this.size = 60,
    this.fontSize = 24,
  });

  @override
  State<PetAvatar> createState() => _PetAvatarState();
}

class _PetAvatarState extends State<PetAvatar> {
  final _imageLoader = AvatarImageLoader();
  Uint8List? get _bytes => _imageLoader.bytes;
  bool get _loading => _imageLoader.loading;

  @override
  void initState() {
    super.initState();
    _imageLoader.addListener(_imageChanged);
    if (widget.avatarUrl.isNotEmpty) {
      _fetchImage(widget.avatarUrl);
    }
  }

  void _imageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _imageLoader.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PetAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.avatarUrl != oldWidget.avatarUrl) _fetchImage(widget.avatarUrl);
  }

  Future<void> _fetchImage(String url) => _imageLoader.load(url);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: _loading
            ? Center(
                child: SizedBox(
                  width: widget.size * 0.35,
                  height: widget.size * 0.35,
                  child: const CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.primary,
                  ),
                ),
              )
            : _bytes != null
            ? Image.memory(
                _bytes!,
                width: widget.size,
                height: widget.size,
                fit: BoxFit.cover,
              )
            : Center(
                child: Text(
                  widget.petName.isNotEmpty ? widget.petName[0] : '?',
                  style: GoogleFonts.outfit(
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
      ),
    );
  }
}
