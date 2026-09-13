import 'package:flutter/material.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_write_result.dart';
import 'package:ai_pet_communication/services/error_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../features/pet/domain/models/pet_model.dart';
import '../../../../../features/pet/application/pet_service.dart';
import '../../../../../features/pet/presentation/pet_form_sheet.dart';
import '../../../../../features/pet/presentation/pet_detail_screen.dart';
import '../../../../../widgets/pet_avatar.dart';
import 'package:ai_pet_communication/app/theme.dart';

class HomePetList extends StatelessWidget {
  final Widget? header;
  final Widget? footer;
  final VoidCallback? onAddPet;
  final String uid;
  final Stream<List<PetModel>>? petsStream;
  final PetService petService;

  const HomePetList({
    super.key,
    this.header,
    this.footer,
    this.onAddPet,
    required this.uid,
    required this.petsStream,
    required this.petService,
  });

  @override
  Widget build(BuildContext context) => StreamBuilder<List<PetModel>>(
    stream: petsStream,
    builder: (context, snapshot) {
      final pets = snapshot.data ?? [];
      return CustomScrollView(
        slivers: [
          if (header != null) SliverToBoxAdapter(child: header),
          if (snapshot.connectionState == ConnectionState.waiting)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              ),
            )
          else if (snapshot.hasError)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('暫時無法載入毛孩資料，請稍後再試。', textAlign: TextAlign.center),
              ),
            )
          else if (pets.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.pets_rounded,
                      size: 64,
                      color: AppColors.accent,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '還沒有新增任何毛小孩喔！',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '先建立毛孩檔案，開始記錄你們的相處。',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      key: const Key('empty-add-pet'),
                      onPressed:
                          onAddPet ??
                          () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => const PetFormSheet(),
                          ),
                      icon: const Icon(Icons.add),
                      label: const Text('新增毛小孩', textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: pets.length,
              itemBuilder: (context, index) =>
                  _buildPetCard(context, pets[index]),
            ),
          if (footer != null) SliverToBoxAdapter(child: footer),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      );
    },
  );

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
                  tooltip: '毛孩選項',
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
                                style: TextStyle(color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          final result = await petService.deletePet(
                            pet.petId,
                            expectedOwnerId: pet.ownerId,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result == PetWriteResult.pendingSync
                                    ? '已從此裝置移除，等待同步刪除'
                                    : '已刪除毛小孩資料',
                              ),
                            ),
                          );
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ErrorService.getErrorMessage(error),
                                ),
                              ),
                            );
                          }
                        }
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
                            color: AppColors.error,
                          ),
                          SizedBox(width: 12),
                          Text('刪除', style: TextStyle(color: AppColors.error)),
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
