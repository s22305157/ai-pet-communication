import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../features/pet/domain/models/pet_model.dart';
import '../../../../../features/pet/application/pet_service.dart';
import '../../../../../features/pet/presentation/pet_form_sheet.dart';
import '../../../../../features/pet/presentation/pet_detail_screen.dart';
import '../../../../../widgets/pet_avatar.dart';
import 'package:ai_pet_communication/app/theme.dart';

class HomePetList extends StatelessWidget {
  final String uid;
  final Stream<List<PetModel>>? petsStream;
  final PetService petService;

  const HomePetList({
    super.key,
    required this.uid,
    required this.petsStream,
    required this.petService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PetModel>>(
      stream: petsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '載入資料時發生錯誤',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final pets = snapshot.data ?? [];

        if (pets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.pets_rounded,
                    size: 80,
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '還沒有新增任何毛小孩喔！',
                  style: GoogleFonts.outfit(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    '點擊右下角的「+」按鈕，\n開始建立您與毛小孩的專屬回憶。',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(
            left: 24,
            right: 24,
            top: 8,
            bottom: 80,
          ),
          itemCount: pets.length,
          itemBuilder: (context, index) {
            final pet = pets[index];
            return _buildPetCard(context, pet);
          },
        );
      },
    );
  }

  Widget _buildPetCard(BuildContext context, PetModel pet) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppStyles.borderRadius),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PetDetailScreen(pet: pet)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 毛小孩頭像
                PetAvatar(
                  avatarUrl: pet.avatarUrl,
                  petName: pet.name,
                  size: 60,
                  fontSize: 24,
                ),
                const SizedBox(width: 16),
                // 毛小孩資訊
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.name,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${pet.species} / ${pet.breed}',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // 選項選單
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppColors.textSecondary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => PetFormSheet(existingPet: pet),
                      );
                    } else if (value == 'delete') {
                      // 確認刪除對話框
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Text(
                            '刪除毛小孩',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          content: Text('確定要刪除 ${pet.name} 的資料嗎？\n(此動作無法復原)'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text(
                                '取消',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text(
                                '刪除',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await petService.deletePet(pet.petId);
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: const [
                          Icon(
                            Icons.edit,
                            size: 20,
                            color: AppColors.textPrimary,
                          ),
                          SizedBox(width: 12),
                          Text('編輯'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: const [
                          Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Colors.redAccent,
                          ),
                          SizedBox(width: 12),
                          Text('刪除', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
