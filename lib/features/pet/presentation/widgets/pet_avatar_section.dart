import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../constants.dart';
import '../../../../injection.dart';
import '../../../../services/error_service.dart';
import '../../domain/models/pet_model.dart';
import '../../application/pet_service.dart';

typedef OnPetUpdatedCallback = void Function(PetModel updatedPet);

class PetAvatarSection extends StatefulWidget {
  final PetModel pet;
  final PetService? petService;
  final OnPetUpdatedCallback onPetUpdated;

  const PetAvatarSection({
    super.key,
    required this.pet,
    required this.onPetUpdated,
    this.petService,
  });

  @override
  State<PetAvatarSection> createState() => _PetAvatarSectionState();
}

class _PetAvatarSectionState extends State<PetAvatarSection> {
  late final PetService _petService = widget.petService ?? getIt<PetService>();
  final ImagePicker _picker = ImagePicker();

  bool _isUploading = false;
  bool _isLoadingAvatar = false;
  Uint8List? _avatarBytes;

  @override
  void initState() {
    super.initState();
    if (widget.pet.avatarUrl.isNotEmpty) {
      _loadAvatarFromUrl(widget.pet.avatarUrl);
    }
  }

  @override
  void didUpdateWidget(covariant PetAvatarSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pet.avatarUrl != oldWidget.pet.avatarUrl) {
      if (widget.pet.avatarUrl.isNotEmpty) {
        _loadAvatarFromUrl(widget.pet.avatarUrl);
      } else {
        setState(() {
          _avatarBytes = null;
        });
      }
    }
  }

  Future<void> _loadAvatarFromUrl(String url) async {
    if (!mounted) return;
    setState(() => _isLoadingAvatar = true);
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _avatarBytes = response.bodyBytes;
          _isLoadingAvatar = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingAvatar = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAvatar = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (file == null) return;

    final Uint8List bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _avatarBytes = bytes;
      _isUploading = true;
    });

    try {
      final imageId = const Uuid().v4();

      // 1. 上傳到 Firebase Storage
      final url = await _petService.uploadPetAvatar(uid, imageId, bytes);

      // 2. 更新 Firestore/本地
      final updatedPet = widget.pet.copyWith(avatarUrl: url);
      await _petService.updatePet(updatedPet.petId, updatedPet);

      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        widget.onPetUpdated(updatedPet);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('頭像更新成功！'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('頭像上傳失敗: ${ErrorService.getErrorMessage(e)}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildAvatarContent() {
    if (_isUploading || _isLoadingAvatar) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      );
    }
    if (_avatarBytes != null) {
      return Image.memory(
        _avatarBytes!,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
      );
    }
    return _buildInitialPlaceholder();
  }

  Widget _buildInitialPlaceholder() {
    return Center(
      child: Text(
        widget.pet.name.isNotEmpty ? widget.pet.name[0] : '?',
        style: GoogleFonts.outfit(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        children: [
          GestureDetector(
            onTap: (_isUploading || _isLoadingAvatar) ? null : _pickAndUploadAvatar,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: ClipOval(child: _buildAvatarContent()),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: (_isUploading || _isLoadingAvatar) ? null : _pickAndUploadAvatar,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
