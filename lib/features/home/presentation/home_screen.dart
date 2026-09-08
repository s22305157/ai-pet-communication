import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_pet_communication/app/theme.dart';
import 'package:ai_pet_communication/features/pet/application/pet_service.dart';
import 'package:ai_pet_communication/features/home/presentation/controllers/home_controller.dart';
import 'package:ai_pet_communication/features/home/presentation/widgets/home_top_bar.dart';
import 'package:ai_pet_communication/features/home/presentation/widgets/home_pet_list.dart';
import 'package:ai_pet_communication/models/user_model.dart';
import 'package:ai_pet_communication/features/auth/application/auth_service.dart';
import 'package:ai_pet_communication/services/ad_service.dart';
import 'package:ai_pet_communication/services/membership_action_handler.dart';
import 'package:ai_pet_communication/app/injection.dart';

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
  late final AuthService _authService =
      widget.authService ?? getIt<AuthService>();
  late final PetService _petService = widget.petService ?? getIt<PetService>();
  late final AdService _adService = widget.adService ?? getIt<AdService>();
  late final MembershipActionHandler _membershipHandler =
      widget.membershipHandler ?? getIt<MembershipActionHandler>();

  late final String _uid = widget.user.uid;
  late final HomeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HomeController(uid: _uid, petService: _petService);
    _controller.setupCloudStatusListener(
      context,
      onFallback: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('雲端連線失敗，目前已切換至本地模式。'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
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
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8.0,
              ),
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
                petsStream: _controller.petsStream,
                petService: _petService,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _controller.handleAddPet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          '新增毛小孩',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
