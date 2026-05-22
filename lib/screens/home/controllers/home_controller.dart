import 'package:flutter/material.dart';
import 'package:ai_pet_communication/features/pet/application/pet_service.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/features/pet/presentation/pet_form_sheet.dart';
import 'package:ai_pet_communication/injection.dart';

class HomeController {
  final PetService _petService;
  late final Stream<List<PetModel>> petsStream;
  VoidCallback? _cloudListener;

  HomeController({
    required String uid,
    PetService? petService,
  }) : _petService = petService ?? getIt<PetService>() {
    petsStream = _petService.watchPetsByOwner(uid);
  }

  void setupCloudStatusListener(BuildContext context, {required VoidCallback onFallback}) {
    _cloudListener = () {
      if (!_petService.isCloudActive.value) {
        onFallback();
      }
    };
    _petService.isCloudActive.addListener(_cloudListener!);
  }

  void dispose() {
    if (_cloudListener != null) {
      _petService.isCloudActive.removeListener(_cloudListener!);
    }
  }

  void handleAddPet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PetFormSheet(),
    );
  }
}
