import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../constants.dart';
import '../domain/models/pet_model.dart';
import '../application/pet_service.dart';
import '../../../../features/readings/data/readings_repository.dart';
import '../../../../features/readings/application/reading_service.dart';
import '../../../../services/ad_service.dart';
import '../../../../services/error_service.dart';
import '../../../../services/auth_service.dart';
import '../../../../screens/profile/settings_screen.dart';
import '../../../../services/membership_action_handler.dart';
import '../../../../injection.dart';
import 'widgets/pet_avatar_section.dart';
import 'widgets/pet_info_card.dart';
import 'widgets/pet_readings_section.dart';
import 'controllers/pet_detail_controller.dart';

class PetDetailScreen extends StatefulWidget {
  final PetModel pet;
  final PetService? petService;
  final ReadingsRepository? readingsRepository;
  final AuthService? authService;
  final AdService? adService;
  final ReadingService? readingService;
  final MembershipActionHandler? membershipHandler;

  const PetDetailScreen({
    super.key,
    required this.pet,
    this.petService,
    this.readingsRepository,
    this.authService,
    this.adService,
    this.readingService,
    this.membershipHandler,
  });

  @override
  State<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends State<PetDetailScreen> {
  late final PetService _petService = widget.petService ?? getIt<PetService>();
  late final ReadingsRepository _readingsRepository = widget.readingsRepository ?? getIt<ReadingsRepository>();
  late final AuthService _authService = widget.authService ?? getIt<AuthService>();
  late final AdService _adService = widget.adService ?? getIt<AdService>();
  late final ReadingService _readingService = widget.readingService ?? getIt<ReadingService>();

  late final PetDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PetDetailController(
      pet: widget.pet,
      petService: _petService,
      membershipHandler: widget.membershipHandler,
    );
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPet = _controller.pet;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          '寵物檔案',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) async {
              if (value == 'edit') {
                await _controller.handleEdit(context);
              } else if (value == 'delete') {
                await _controller.handleDelete(
                  context,
                  onDeleted: () {
                    if (mounted) Navigator.pop(context);
                  },
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: const [
                    Icon(Icons.edit_note_rounded, color: AppColors.textPrimary),
                    SizedBox(width: 12),
                    Text('編輯資料'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: const [
                    Icon(Icons.delete_outline, color: Colors.redAccent),
                    SizedBox(width: 12),
                    Text('刪除毛小孩', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            PetAvatarSection(
              pet: currentPet,
              petService: _petService,
              onPetUpdated: (updatedPet) {
                _controller.updatePet(updatedPet);
              },
            ),
            const SizedBox(height: 16),
            Text(
              currentPet.name,
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (currentPet.species.isNotEmpty || currentPet.breed.isNotEmpty)
              Text(
                '${currentPet.species}${currentPet.breed.isNotEmpty ? ' · ${currentPet.breed}' : ''}',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            const SizedBox(height: 32),
            PetInfoCard(pet: currentPet),
            const SizedBox(height: 32),
            PetReadingsSection(
              pet: currentPet,
              readingsRepository: _readingsRepository,
              readingService: _readingService,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomAction(context, currentPet),
    );
  }

  Widget _buildBottomAction(BuildContext context, PetModel currentPet) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _controller.handleStartCommunication(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    '開始與 ${currentPet.name} 溝通',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
