import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'constants.dart';
import 'services/auth_service.dart';
import 'services/pet_service.dart';
import 'models/pet_model.dart';
import 'screens/pets/pet_form_sheet.dart';
import 'screens/pets/pet_detail_screen.dart';
import 'widgets/pet_avatar.dart';
import 'screens/profile/profile_screen.dart';
import 'models/user_model.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final PetService _petService = PetService();
  
  late final String _uid = widget.user.uid;
  Stream<List<PetModel>>? _petsStream;

  @override
  void initState() {
    super.initState();
    // 初始化時直接建立資料流，不再需要判斷 UID 是否改變（因為切換帳號會重建整個 HomeScreen）
    _petsStream = _petService.watchPetsByOwner(_uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(),
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
              child: _buildPetList(_uid),
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

  Widget _buildPetList(String uid) {
    return StreamBuilder<List<PetModel>>(
      stream: _petsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    '載入資料時發生錯誤',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 14),
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
                Icon(Icons.pets, size: 64, color: AppColors.textSecondary.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text(
                  '還沒有新增任何毛小孩喔！\n點擊右下角按鈕新增',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 8, bottom: 80),
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
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.8)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppStyles.borderRadius),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PetDetailScreen(pet: pet),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Pet Avatar
                PetAvatar(
                  avatarUrl: pet.avatarUrl,
                  petName: pet.name,
                  size: 60,
                  fontSize: 24,
                ),
                const SizedBox(width: 16),
                // Pet Info
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
                // Options Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => PetFormSheet(existingPet: pet),
                      );
                    } else if (value == 'delete') {
                      // Confirm delete
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Text('刪除毛小孩', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                          content: Text('確定要刪除 ${pet.name} 的資料嗎？\n(此動作無法復原)'),
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
                      
                      if (confirm == true && pet.petId != null) {
                        await _petService.deletePet(pet.petId!);
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: const [
                          Icon(Icons.edit, size: 20, color: AppColors.textPrimary),
                          SizedBox(width: 12),
                          Text('編輯'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: const [
                          Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
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

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左側：用戶頭像與問候
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
                child: Hero(
                  tag: 'profile_avatar',
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.surface,
                    backgroundImage: widget.user.photoURL != null 
                        ? NetworkImage(widget.user.photoURL!) 
                        : null,
                    child: widget.user.photoURL == null
                        ? const Icon(
                            Icons.person_rounded,
                            color: AppColors.primary,
                            size: 28,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    widget.user.displayName ?? '毛小孩主人',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // 右側區塊：同步狀態與點數
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 同步狀態指示器 (Sync Indicator)
              StreamBuilder<void>(
                stream: FirebaseFirestore.instance.snapshotsInSync(),
                builder: (context, _) {
                  // 我們可以使用 snapshotsInSync 來得知何時所有本地寫入都已完成同步
                  return FutureBuilder<bool>(
                    future: Future.value(true), // 這裡可以進一步擴充檢查真實網路
                    builder: (context, netSnapshot) {
                      return Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () async {
                            final isPro = await _authService.isProUser();
                            if (!isPro) {
                              _showUpgradeDialog(context);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('您的資料已由雲端安全守護')),
                              );
                            }
                          },
                          child: Tooltip(
                            message: '資料存儲狀態',
                            child: StreamBuilder<UserModel?>(
                              stream: _authService.getUserStream(),
                              builder: (context, userSnapshot) {
                                final user = userSnapshot.data;
                                
                                // 如果是 Free 用戶，顯示本地儲存圖示
                                if (user == null || user.membershipType == 'free') {
                                  return const Icon(
                                    Icons.storage_rounded,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  );
                                }

                                // 如果是 Pro 用戶，顯示雲端同步狀態
                                return StreamBuilder<QuerySnapshot>(
                                  // 監聽是否有待處理的寫入 (Pending Writes)
                                  stream: FirebaseFirestore.instance.collection('pets').where('owner_id', isEqualTo: user.uid).snapshots(),
                                  builder: (context, snapshot) {
                                    bool hasPending = snapshot.data?.metadata.hasPendingWrites ?? false;
                                    bool isFromCache = snapshot.data?.metadata.isFromCache ?? false;

                                    if (hasPending) {
                                      return const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                                        ),
                                      );
                                    }

                                    return Icon(
                                      isFromCache ? Icons.cloud_off_rounded : Icons.cloud_done_outlined,
                                      size: 18,
                                      color: isFromCache ? Colors.orange : Colors.green.withOpacity(0.8),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              // 即時點數顯示 (Point Pill)
              StreamBuilder<UserModel?>(
                stream: _authService.getUserStream(),
                builder: (context, snapshot) {
                  final user = snapshot.data;
                  final points = user?.points ?? 0;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: Colors.white.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.monetization_on_rounded,
                          color: AppColors.secondary,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$points PT',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: Colors.amber),
            const SizedBox(width: 12),
            Text('升級至 Pro 方案', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('解鎖強大功能，守護您的毛小孩資料：', style: GoogleFonts.outfit()),
            const SizedBox(height: 16),
            _buildFeatureItem(Icons.cloud_sync_rounded, '雲端即時備份與同步'),
            _buildFeatureItem(Icons.devices_rounded, '跨裝置存取寵物檔案'),
            _buildFeatureItem(Icons.auto_awesome_rounded, '無限制 AI 寵物溝通次數'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('稍後再說', style: GoogleFonts.outfit(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('立即了解', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.secondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: GoogleFonts.outfit(fontSize: 14))),
        ],
      ),
    );
  }
}

