import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants.dart';
import 'features/pet/application/pet_service.dart';
import 'features/pet/domain/models/pet_model.dart';
import 'features/pet/presentation/pet_form_sheet.dart';
import 'screens/home/widgets/home_top_bar.dart';
import 'screens/home/widgets/home_pet_list.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
import 'services/ad_service.dart';
import 'services/membership_action_handler.dart';
import 'injection.dart';

class HomeScreen extends StatefulWidget {
  final UserModel user;
  final AuthService? authService;
  final PetService? petService;
  final AdService? adService;
  final MembershipActionHandler? membershipHandler;

  const HomeScreen({
    super.key,
    required this.user,
    this.authService,
    this.petService,
    this.adService,
    this.membershipHandler,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AuthService _authService = widget.authService ?? getIt<AuthService>();
  late final PetService _petService = widget.petService ?? getIt<PetService>();
  late final AdService _adService = widget.adService ?? getIt<AdService>();
  late final MembershipActionHandler _membershipHandler = widget.membershipHandler ?? getIt<MembershipActionHandler>();

  late final String _uid = widget.user.uid;
  Stream<List<PetModel>>? _petsStream;

  @override
  void initState() {
    super.initState();
    _petService.isCloudActive.addListener(_onCloudStatusChanged);
    _petsStream = _petService.watchPetsByOwner(_uid);
  }

  void _onCloudStatusChanged() {
    if (!_petService.isCloudActive.value && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('雲端連線失敗，目前已切換至本地模式。'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _petService.isCloudActive.removeListener(_onCloudStatusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeTopBar(
              user: widget.user,
              authService: _authService,
              petService: _petService,
              adService: _adService,
              membershipHandler: _membershipHandler,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '我的毛小孩',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: HomePetList(
                uid: _uid,
                petsStream: _petsStream,
                petService: _petService,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const PetFormSheet(),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          '新增毛小孩',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
