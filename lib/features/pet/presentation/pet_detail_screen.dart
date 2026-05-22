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

  const PetDetailScreen({
    super.key,
    required this.pet,
    this.petService,
    this.readingsRepository,
    this.authService,
    this.adService,
    this.readingService,
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
    final user = await _authService.getUserData();
    if (user == null) return;

    final type = user.membershipType?.toLowerCase() ?? 'free';
    
    if (type == 'pro') {
      _navigateToAI(context);
    } else if (type == 'plus') {
      _showUpgradeDialog(context, currentTier: 'plus');
    } else {
      if (user.points > 0) {
        _showPointConsumptionDialog(context);
      } else {
        _showUpgradeDialog(context, currentTier: 'free');
      }
    }
  }

  void _showPointConsumptionDialog(BuildContext context) {
    bool isProcessing = false;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('開始溝通', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('本次溝通將消耗 1 PT 點數。\n升級會員可享優惠或無限次溝通！'),
              if (isProcessing) ...[
                const SizedBox(height: 20),
                const CircularProgressIndicator(color: AppColors.primary),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(context),
              child: Text('稍後', style: GoogleFonts.outfit(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: isProcessing ? null : () async {
                setDialogState(() => isProcessing = true);
                try {
                  await _authService.consumePoints(1);
                  if (context.mounted) {
                    Navigator.pop(context);
                    _navigateToAI(context, pointDeducted: true);
                  }
                } catch (e) {
                  if (context.mounted) {
                    setDialogState(() => isProcessing = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('扣點失敗: ${ErrorService.getErrorMessage(e)}')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('確認扣點', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToAI(BuildContext context, {bool pointDeducted = false}) async {
    final user = await _authService.getUserData();
    if (user != null && (user.membershipType?.toLowerCase() ?? 'free') != 'pro') {
      await _adService.showInterstitialAd();
    }

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PetCommunicationInputScreen(pet: _currentPet),
        ),
      );
    }
  }

  void _showUpgradeDialog(BuildContext context, {required String currentTier}) {
    final String targetTier = currentTier == 'free' ? 'Plus' : 'Pro';
    final Color tierColor = currentTier == 'free' ? Colors.blue : Colors.amber;
    final String message = currentTier == 'free' 
        ? '升級至 Plus 方案即可開啟雲端同步並獲得額外點數加成！'
        : '升級至 Pro 尊榮方案，即刻享受無限次 AI 溝通與最優先支援。';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: tierColor),
            const SizedBox(width: 12),
            Text('解鎖 $targetTier 方案', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('稍後再說', style: GoogleFonts.outfit(color: AppColors.textSecondary)),
          ),
          if (currentTier == 'free')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showRewardedAdOption(context);
              },
              child: const Text('觀看影片領點數', style: TextStyle(color: AppColors.secondary)),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: tierColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('了解 $targetTier 方案', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRewardedAdOption(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.video_collection_rounded, color: AppColors.secondary),
            const SizedBox(width: 12),
            Text('獲得點數', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('觀看一段短片，即可免費獲得 1 PT 溝通點數！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('稍後再說', style: GoogleFonts.outfit(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _adService.watchAdForPoints(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('觀看影片', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
