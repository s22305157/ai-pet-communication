import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final pet = PetModel(
      petId: widget.existingPet?.petId,
      ownerId: uid,
      name: nameController.text.trim(),
      species: speciesController.text.trim(),
      breed: breedController.text.trim(),
      gender: genderController.text.trim(),
      birthday: birthdayController.text.trim(),
      personality: personalityController.text.trim(),
      avatarUrl: '',
    );

    if (widget.existingPet == null) {
      await _petService.createPet(pet);
    } else {
      await _petService.updatePet(widget.existingPet!.petId!, pet);
    }

    if (mounted) Navigator.pop(context);
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
                  widget.existingPet == null ? '新增寵物朋友' : '編輯寵物資料',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: nameController,
                  decoration: _buildInputDecoration('寵物名字'),
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
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppStyles.borderRadius),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
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
