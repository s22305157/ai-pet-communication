import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';

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
  Uint8List? _bytes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.avatarUrl.isNotEmpty) {
      _fetchImage(widget.avatarUrl);
    }
  }

  @override
  void didUpdateWidget(PetAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // URL 變更時重新載入（例如用戶更換頭像後列表刷新）
    if (oldWidget.avatarUrl != widget.avatarUrl &&
        widget.avatarUrl.isNotEmpty) {
      _fetchImage(widget.avatarUrl);
    }
  }

  Future<void> _fetchImage(String url) async {
    setState(() => _loading = true);
    try {
      print('Fetching avatar from: $url');
      final response = await http.get(Uri.parse(url));
      print('Avatar fetch status: ${response.statusCode}');
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _bytes = response.bodyBytes;
          _loading = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      print('Error fetching avatar: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
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
