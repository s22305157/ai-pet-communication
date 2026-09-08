import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_pet_communication/widgets/avatar_image_loader.dart';
import 'package:ai_pet_communication/features/pet/application/pet_form_controller.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_write_result.dart';
import 'package:ai_pet_communication/features/auth/application/auth_service.dart';
import 'package:ai_pet_communication/app/theme.dart';
import 'package:ai_pet_communication/app/injection.dart';
import 'package:ai_pet_communication/services/error_service.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/features/pet/application/pet_service.dart';

typedef OnPetUpdatedCallback = void Function(PetModel updatedPet);

class PetAvatarSection extends StatefulWidget {
  final PetModel pet;
  final PetService? petService;
  final PetFormController? formController;
  final OnPetUpdatedCallback onPetUpdated;

  const PetAvatarSection({
    super.key,
    required this.pet,
    required this.onPetUpdated,
    this.petService,
    this.formController,
  });

  @override
  State<PetAvatarSection> createState() => _PetAvatarSectionState();
}

class _PetAvatarSectionState extends State<PetAvatarSection> {
  late final PetService _petService = widget.petService ?? getIt<PetService>();
  late final _formController =
      widget.formController ??
      PetFormController(
        service: _petService,
        currentUid: () async => (await getIt<AuthService>().getUserData())?.uid,
      );

  bool _isUploading = false;
  final _imageLoader = AvatarImageLoader();
  bool get _isLoadingAvatar => _imageLoader.loading;
  Uint8List? get _avatarBytes => _imageLoader.bytes;

  @override
  void initState() {
    super.initState();
    _imageLoader.addListener(_imageChanged);
    if (widget.pet.avatarUrl.isNotEmpty) {
      _loadAvatarFromUrl(widget.pet.avatarUrl);
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
  void didUpdateWidget(covariant PetAvatarSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pet.avatarUrl != oldWidget.pet.avatarUrl) {
      _loadAvatarFromUrl(widget.pet.avatarUrl);
    }
  }

  Future<void> _loadAvatarFromUrl(String url) => _imageLoader.load(url);

  Future<void> _pickAndUploadAvatar() async {
    setState(() => _isUploading = true);
    try {
      final image = await _formController.pickAndUpload();
      if (!mounted || image == null) return;
      final updatedPet = widget.pet.copyWith(avatarUrl: image.url);
      final result = await _formController.save(updatedPet, isNew: false);
      if (!mounted) return;
      if (result != PetWriteResult.conflict) {
        widget.onPetUpdated(updatedPet);
        await _imageLoader.load(image.url);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PetFormController.message(result))),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorService.getErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
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
            onTap: (_isUploading || _isLoadingAvatar)
                ? null
                : _pickAndUploadAvatar,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
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
              onTap: (_isUploading || _isLoadingAvatar)
                  ? null
                  : _pickAndUploadAvatar,
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
