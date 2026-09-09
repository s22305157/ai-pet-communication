import 'dart:typed_data';

import 'package:ai_pet_communication/features/pet/application/pet_form_controller.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_write_result.dart';
import 'package:ai_pet_communication/features/auth/application/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ai_pet_communication/app/theme.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/features/pet/application/pet_service.dart';
import '../../../../services/error_service.dart';
import 'package:ai_pet_communication/app/injection.dart';

class PetFormSheet extends StatefulWidget {
  final PetModel? existingPet;
  final PetService? petService;
  final PetFormController? formController;

  const PetFormSheet({
    super.key,
    this.existingPet,
    this.petService,
    this.formController,
  });

  @override
  State<PetFormSheet> createState() => _PetFormSheetState();
}

class _PetFormSheetState extends State<PetFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _petService = widget.petService ?? getIt<PetService>();
  late final _formController =
      widget.formController ??
      PetFormController(
        service: _petService,
        currentUid: () async => (await getIt<AuthService>().getUserData())?.uid,
      );
  bool _isSaving = false;
  late final Future<String?> _originUid;
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
  late TextEditingController colorController;
  late TextEditingController weightController;

  @override
  void initState() {
    super.initState();
    final pet = widget.existingPet;
    _originUid = pet == null
        ? _formController.currentUid()
        : Future.value(pet.ownerId);

    nameController = TextEditingController(text: pet?.name ?? '');
    speciesController = TextEditingController(text: pet?.species ?? '');
    breedController = TextEditingController(text: pet?.breed ?? '');
    genderController = TextEditingController(text: pet?.gender ?? '');
    birthdayController = TextEditingController(text: pet?.birthday ?? '');
    personalityController = TextEditingController(text: pet?.personality ?? '');
    colorController = TextEditingController(text: pet?.color ?? '');
    weightController = TextEditingController(
      text: pet?.weight.toString() ?? '0.0',
    );
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
    colorController.dispose();
    weightController.dispose();
    super.dispose();
  }

  // ── 選取頭像並上傳至 Firebase Cloud Storage ──────────────────────────────
  Future<void> _pickAndUploadAvatar() async {
    setState(() => _isUploadingAvatar = true);
    try {
      final image = await _formController.pickAndUpload();
      if (!mounted || image == null) return;
      setState(() {
        _pickedImageBytes = image.bytes;
        _avatarUrl = image.url;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorService.getErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  // ── 選取日期 ──────────────────────────────────────────────────────────────
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: widget.existingPet?.birthday != null
          ? DateTime.tryParse(widget.existingPet!.birthday) ?? DateTime.now()
          : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.accent,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        birthdayController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  // ── 儲存寵物資料 ──────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final uid = await _formController.currentUid();
      final originUid = await _originUid;
      if (!mounted) return;
      if (uid == null) throw const PetWriteFailure('請先登入');
      if (uid != originUid) {
        throw const PetWriteFailure('帳號已變更，請重新開啟表單');
      }
      final pet = PetModel(
        petId: widget.existingPet?.petId ?? '',
        ownerId: originUid!,
        name: nameController.text.trim(),
        species: speciesController.text.trim(),
        breed: breedController.text.trim(),
        gender: genderController.text.trim(),
        birthday: birthdayController.text.trim(),
        personality: personalityController.text.trim(),
        avatarUrl: _avatarUrl,
        color: colorController.text.trim(),
        weight: double.tryParse(weightController.text.trim()) ?? 0.0,
        createdAt: widget.existingPet?.createdAt,
        updatedAt: widget.existingPet?.updatedAt,
      );

      final result = await _formController.save(
        pet,
        isNew: widget.existingPet == null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(PetFormController.message(result)),
            backgroundColor: AppColors.secondary,
          ),
        );
        if (result != PetWriteResult.conflict) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorService.getErrorMessage(e)),
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
                color: AppColors.primary.withValues(alpha: 0.1),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(child: _buildAvatarContent()),
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt,
                        size: 14,
                        color: Colors.white,
                      ),
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
        errorBuilder: (_, _, _) => _defaultAvatarIcon(),
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
          Icon(
            Icons.pets_rounded,
            size: 32,
            color: AppColors.primary.withValues(alpha: 0.6),
          ),
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
      labelStyle: TextStyle(
        color: AppColors.textSecondary.withValues(alpha: 0.8),
      ),
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.02),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
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
          autovalidateMode: AutovalidateMode.onUserInteraction,
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
                      color: Colors.grey.withValues(alpha: 0.3),
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
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
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
                        validator: (v) =>
                            (v == null || v.isEmpty) ? '請輸入種類' : null,
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
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            ['公', '母', '未知'].contains(genderController.text)
                            ? genderController.text
                            : null,
                        decoration: _buildInputDecoration('性別'),
                        items: ['公', '母', '未知']
                            .map(
                              (label) => DropdownMenuItem(
                                value: label,
                                child: Text(label, style: GoogleFonts.outfit()),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => genderController.text = v ?? ''),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? '請選擇性別' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: birthdayController,
                        readOnly: true,
                        onTap: _selectDate,
                        decoration: _buildInputDecoration('生日 (點擊選擇)'),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? '請選擇生日' : null,
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
                        controller: colorController,
                        decoration: _buildInputDecoration('毛色 (例如：奶油色)'),
                        style: GoogleFonts.outfit(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: weightController,
                        decoration: _buildInputDecoration('體重 (kg)'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return '請輸入體重';
                          final weight = double.tryParse(v);
                          if (weight == null || weight <= 0) return '請輸入有效體重';
                          return null;
                        },
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
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppStyles.borderRadius,
                      ),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
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
