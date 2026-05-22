import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../constants.dart';
import '../domain/models/pet_model.dart';
import '../application/pet_service.dart';
import '../../../../features/readings/data/readings_repository.dart';
import '../../../../features/readings/application/reading_service.dart';
import '../../../../features/chat/presentation/pet_communication_input_screen.dart';
import '../../../../services/ad_service.dart';
import '../../../../services/error_service.dart';
import '../../../../services/auth_service.dart';
import '../../../../screens/profile/settings_screen.dart';
import '../../../../services/membership_action_handler.dart';
import '../../../../injection.dart';
import 'widgets/pet_avatar_section.dart';
import 'widgets/pet_info_card.dart';
import 'widgets/pet_readings_section.dart';
import 'pet_form_sheet.dart';

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
  late PetModel _currentPet;
  late final PetService _petService = widget.petService ?? getIt<PetService>();
  late final ReadingsRepository _readingsRepository = widget.readingsRepository ?? getIt<ReadingsRepository>();
  late final AuthService _authService = widget.authService ?? getIt<AuthService>();
  late final AdService _adService = widget.adService ?? getIt<AdService>();
  late final ReadingService _readingService = widget.readingService ?? getIt<ReadingService>();
  late final MembershipActionHandler _membershipHandler = widget.membershipHandler ?? getIt<MembershipActionHandler>();

  @override
  void initState() {
    super.initState();
    _currentPet = widget.pet;
  }

  @override
  Widget build(BuildContext context) {
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
                await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => PetFormSheet(
                    existingPet: _currentPet,
                    petService: _petService,
                  ),
                );
                // 表單關閉後，從 PetService 重新獲取最新資料並刷新 UI
                final refreshedPet = await _petService.getPet(_currentPet.petId);
                if (refreshedPet != null && mounted) {
                  setState(() {
                    _currentPet = refreshedPet;
                  });
                }
              } else if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text('刪除毛小孩', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    content: Text('確定要刪除 ${_currentPet.name} 的資料嗎？\n(此動作無法復原)'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('取消', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('刪除', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  await _petService.deletePet(_currentPet.petId);
                  if (mounted) Navigator.pop(context); // 返回首頁
                }
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
              pet: _currentPet,
              petService: _petService,
              onPetUpdated: (updatedPet) {
                setState(() {
                  _currentPet = updatedPet;
                });
              },
            ),
            const SizedBox(height: 16),
            Text(
              _currentPet.name,
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (_currentPet.species.isNotEmpty || _currentPet.breed.isNotEmpty)
              Text(
                '${_currentPet.species}${_currentPet.breed.isNotEmpty ? ' · ${_currentPet.breed}' : ''}',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            const SizedBox(height: 32),
            PetInfoCard(pet: _currentPet),
            const SizedBox(height: 32),
            PetReadingsSection(
              pet: _currentPet,
              readingsRepository: _readingsRepository,
              readingService: _readingService,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomAction(context),
    );
  }

  Widget _buildBottomAction(BuildContext context) {
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
              onPressed: () => _handleStartCommunication(context),
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
                    '開始與 ${_currentPet.name} 溝通',
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

  Future<void> _handleStartCommunication(BuildContext context) async {
    await _membershipHandler.handleStartCommunication(
      context,
      _currentPet,
      onAllowed: () => _navigateToAI(context),
    );
  }

  Future<void> _navigateToAI(BuildContext context) async {
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PetCommunicationInputScreen(pet: _currentPet),
        ),
      );
    }
  }
}
