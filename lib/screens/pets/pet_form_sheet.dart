import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../constants.dart';
import '../../models/pet_model.dart';
import '../../services/pet_service.dart';

class PetFormSheet extends StatefulWidget {
  final PetModel? existingPet;

  const PetFormSheet({super.key, this.existingPet});

  @override
  State<PetFormSheet> createState() => _PetFormSheetState();
}

class _PetFormSheetState extends State<PetFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _petService = PetService();
  final _picker = ImagePicker();
  bool _isSaving = false;
  bool _isUploadingAvatar = false;

  // 目前選取的圖片 bytes（用於 Web）或本地路徑
  Uint8List? _pickedImageBytes;
  // 已上傳至 Firebase Storage 的 URL
  String _avatarUrl = '';

  late TextEditingController nameController;
  late TextEditingController speciesController;
  late TextEditingController breedController;
  late TextEditingController genderController;
  late TextEditingController birthdayController;
  late TextEditingController personalityController;

  @override
  void initState() {
    super.initState();
    final pet = widget.existingPet;

    nameController = TextEditingController(text: pet?.name ?? '');
    speciesController = TextEditingController(text: pet?.species ?? '');
    breedController = TextEditingController(text: pet?.breed ?? '');
    genderController = TextEditingController(text: pet?.gender ?? '');
    birthdayController = TextEditingController(text: pet?.birthday ?? '');
    personalityController = TextEditingController(text: pet?.personality ?? '');
    _avatarUrl = pet?.avatarUrl ?? '';
  }

  @override
  void dispose() {
    nameController.dispose();
    speciesController.dispose();
    breedController.dispose();
    genderController.dispose();
    birthdayController.dispose();
    personalityController.dispose();
    super.dispose();
  }

  // ── 選取頭像並上傳至 Firebase Cloud Storage ──────────────────────────────
  Future<void> _pickAndUploadAvatar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // 從相簿選取圖片（Web / Mobile 都相容）
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _isUploadingAvatar = true);

    try {
      final Uint8List bytes = await file.readAsBytes();
      final imageId = const Uuid().v4();

      // 上傳至 Firebase Storage：pets/{uid}/{imageId}.jpg
      final url = await _petService.uploadPetAvatar(uid, imageId, bytes);

      setState(() {
        _pickedImageBytes = bytes;
        _avatarUrl = url;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('頭像上傳成功！'),
            backgroundColor: AppColors.secondary,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('頭像上傳失敗：$e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  // ── 儲存寵物資料 ──────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final pet = PetModel(
        petId: widget.existingPet?.petId,
        ownerId: uid,
        name: nameController.text.trim(),
        species: speciesController.text.trim(),
        breed: breedController.text.trim(),
        gender: genderController.text.trim(),
        birthday: birthdayController.text.trim(),
        personality: personalityController.text.trim(),
        avatarUrl: _avatarUrl, // 已上傳的 Cloud Storage 公開 URL
      );

      if (widget.existingPet == null) {
        await _petService.createPet(pet);
      } else {
        await _petService.updatePet(widget.existingPet!.petId!, pet);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingPet == null ? '新增成功！' : '更新成功！'),
            backgroundColor: AppColors.secondary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('儲存失敗：$e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── 頭像預覽 Widget ───────────────────────────────────────────────────────
  Widget _buildAvatarPicker() {
    return Center(
      child: Stack(
        children: [
          GestureDetector(
            onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.1),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.4),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.15),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: _buildAvatarContent(),
              ),
            ),
          ),
          // 右下角相機 icon
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: _isUploadingAvatar
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.camera_alt, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarContent() {
    // 優先顯示剛選取的本機 bytes（即時預覽）
    if (_pickedImageBytes != null) {
      return Image.memory(_pickedImageBytes!, fit: BoxFit.cover);
    }
    // 其次顯示已儲存的網路 URL（編輯模式）
    if (_avatarUrl.isNotEmpty) {
      return Image.network(
        _avatarUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultAvatarIcon(),
      );
    }
    // 預設 placeholder
    return _defaultAvatarIcon();
  }

  Widget _defaultAvatarIcon() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pets_rounded, size: 32, color: AppColors.primary.withOpacity(0.6)),
          const SizedBox(height: 4),
          Text(
            '上傳頭像',
            style: GoogleFonts.outfit(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.8)),
      filled: true,
      fillColor: Colors.black.withOpacity(0.02),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 拖動把手
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.existingPet == null ? '新增毛小孩' : '編輯毛小孩',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // ── 頭像選取區 ──
                _buildAvatarPicker(),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '點擊頭像從相簿選取照片',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.textSecondary.withOpacity(0.7),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── 表單欄位 ──
                TextFormField(
                  controller: nameController,
                  decoration: _buildInputDecoration('毛小孩姓名'),
                  validator: (v) => (v == null || v.isEmpty) ? '請輸入名字' : null,
                  style: GoogleFonts.outfit(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: speciesController,
                        decoration: _buildInputDecoration('種類 (例如：狗、貓)'),
                        style: GoogleFonts.outfit(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: breedController,
                        decoration: _buildInputDecoration('品種 (例如：柴犬)'),
                        style: GoogleFonts.outfit(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: genderController,
                        decoration: _buildInputDecoration('性別'),
                        style: GoogleFonts.outfit(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: birthdayController,
                        decoration: _buildInputDecoration('生日/年齡'),
                        style: GoogleFonts.outfit(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: personalityController,
                  decoration: _buildInputDecoration('個性特徵 (例如：愛撒嬌、貪吃)'),
                  maxLines: 3,
                  style: GoogleFonts.outfit(),
                ),
                const SizedBox(height: 32),

                // ── 儲存按鈕 ──
                ElevatedButton(
                  onPressed: (_isSaving || _isUploadingAvatar) ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppStyles.borderRadius),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          '儲存資料',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
