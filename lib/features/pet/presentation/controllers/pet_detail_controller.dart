import 'package:flutter/material.dart';
import '../../domain/models/pet_write_result.dart';
import 'package:ai_pet_communication/services/error_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/features/pet/application/pet_service.dart';
import 'package:ai_pet_communication/features/pet/presentation/pet_form_sheet.dart';
import 'package:ai_pet_communication/features/chat/presentation/pet_communication_input_screen.dart';
import 'package:ai_pet_communication/services/membership_action_handler.dart';
import 'package:ai_pet_communication/app/theme.dart';
import 'package:ai_pet_communication/app/injection.dart';

class PetDetailController extends ChangeNotifier {
  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  PetModel _pet;
  final PetService _petService;
  final MembershipActionHandler? _membershipHandlerOverride;

  PetDetailController({
    required PetModel pet,
    PetService? petService,
    MembershipActionHandler? membershipHandler,
  }) : _pet = pet,
       _petService = petService ?? getIt<PetService>(),
       _membershipHandlerOverride = membershipHandler;

  MembershipActionHandler get _membershipHandler =>
      _membershipHandlerOverride ?? getIt<MembershipActionHandler>();

  PetModel get pet => _pet;

  Future<void> refreshPet() async {
    final refreshed = await _petService.getPet(_pet.petId);
    if (!_disposed && refreshed != null) {
      _pet = refreshed;
      notifyListeners();
    }
  }

  void updatePet(PetModel updatedPet) {
    _pet = updatedPet;
    notifyListeners();
  }

  Future<void> handleEdit(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PetFormSheet(existingPet: _pet, petService: _petService),
    );
    await refreshPet();
  }

  Future<void> handleDelete(
    BuildContext context, {
    required VoidCallback onDeleted,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '刪除毛小孩',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text('確定要刪除 ${_pet.name} 的資料嗎？\n(此動作無法復原)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              '取消',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final result = await _petService.deletePet(
          _pet.petId,
          expectedOwnerId: _pet.ownerId,
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
        onDeleted();
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ErrorService.getErrorMessage(error))),
          );
        }
      }
    }
  }

  Future<void> handleStartCommunication(BuildContext context) async {
    await _membershipHandler.handleStartCommunication(
      context,
      _pet,
      onAllowed: (creditReservationId) {
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PetCommunicationInputScreen(
                pet: _pet,
                creditReservationId: creditReservationId,
              ),
            ),
          );
        }
      },
    );
  }
}
