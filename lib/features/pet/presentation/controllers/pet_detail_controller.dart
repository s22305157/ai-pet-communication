import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/features/pet/application/pet_service.dart';
import 'package:ai_pet_communication/features/pet/presentation/pet_form_sheet.dart';
import 'package:ai_pet_communication/features/chat/presentation/pet_communication_input_screen.dart';
import 'package:ai_pet_communication/services/membership_action_handler.dart';
import 'package:ai_pet_communication/constants.dart';
import 'package:ai_pet_communication/injection.dart';

class PetDetailController extends ChangeNotifier {
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
    if (refreshed != null) {
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
      await _petService.deletePet(_pet.petId);
      onDeleted();
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
