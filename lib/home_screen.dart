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
import 'screens/profile/settings_screen.dart';
import 'services/ad_service.dart';

class HomeScreen extends StatefulWidget {
  final UserModel user;
  final PetService? petService;
  final AuthService? authService;

  const HomeScreen({
    super.key,
    required this.user,
    this.petService,
    this.authService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PetService _petService = widget.petService ?? PetService();
  late final AuthService _authService = widget.authService ?? AuthService();
  
  late final String _uid = widget.user.uid;
  Stream<List<PetModel>>? _petsStream;

  @override
  void initState() {
    super.initState();
    _petService.isCloudActive.addListener(_onCloudStatusChanged);
    // 初始化時直接建立資料流，不再需要判斷 UID 是否改變（因為切換帳號會重建整個 HomeScreen）
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
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.pets_rounded,
                    size: 80,
                    color: AppColors.primary.withOpacity(0.2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '還沒有新增任何毛小孩喔！',
                  style: GoogleFonts.outfit(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    '點擊右下角的「+」按鈕，\n開始建立您與毛小孩的專屬回憶。',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                      height: 1.5,
                    ),
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
                      // 確認刪除對話框
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
                child: StreamBuilder<UserModel?>(
                  stream: _authService.getUserStream(),
                  builder: (context, userSnap) {
                    final tier = userSnap.data?.membershipType?.toLowerCase() ?? 'free';
                    final borderColor = tier == 'pro'
                        ? Colors.amber
                        : tier == 'plus'
                            ? Colors.blue
                            : Colors.grey.shade400;
                    return Hero(
                      tag: 'profile_avatar',
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor, width: 2.5),
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.surface,
                          backgroundImage: widget.user.photoURL != null
                              ? NetworkImage(widget.user.photoURL!)
                              : null,
                          child: widget.user.photoURL == null
                              ? Icon(Icons.person_rounded, color: borderColor, size: 26)
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StreamBuilder<UserModel?>(
                    stream: _authService.getUserStream(),
                    builder: (context, userSnap) {
                      final tier = userSnap.data?.membershipType?.toLowerCase() ?? 'free';
                      final nameColor = tier == 'pro'
                          ? Colors.amber.shade700
                          : tier == 'plus'
                              ? Colors.blue.shade700
                              : AppColors.textPrimary;
                      final firestoreName = userSnap.data?.displayName;
                      final authName = widget.user.displayName;
                      
                      // 優先順序：Firestore 名稱 -> Auth 名稱 -> 預設名稱
                      String displayName = '毛小孩主人';
                      if (firestoreName != null && firestoreName.isNotEmpty) {
                        displayName = firestoreName;
                      } else if (authName != null && authName.isNotEmpty) {
                        displayName = authName;
                      }

                      return Row(
                        children: [
                          Text(
                            displayName,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: nameColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 測試用：後台加點按鈕
                          GestureDetector(
                            onTap: () async {
                              try {
                                await _authService.consumePoints(-15);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('已為您領取 15 點測試點數！')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('加點失敗: $e')),
                                  );
                                }
                              }
                            },
                            child: const Icon(Icons.card_giftcard_rounded, size: 20, color: AppColors.secondary),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          
          // 右側區塊：同步狀態與點數
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // P2: 同步與資料來源提示 UI
              ValueListenableBuilder<bool>(
                valueListenable: _petService.isSyncing,
                builder: (context, isSyncing, _) {
                  if (isSyncing) {
                    return const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                        ),
                      ),
                    );
                  }
                  
                  return ValueListenableBuilder<bool>(
                    valueListenable: _petService.isCloudActive,
                    builder: (context, isCloud, _) {
                      return StreamBuilder<UserModel?>(
                        stream: _authService.getUserStream(),
                        builder: (context, userSnap) {
                          final hasCloudSupport = userSnap.data?.membershipType != 'free';
                          
                          // 根據狀態決定顏色與圖示
                          Color iconColor;
                          IconData iconData;
                          String tooltip;

                          if (!hasCloudSupport) {
                            iconColor = AppColors.textSecondary.withOpacity(0.5);
                            iconData = Icons.storage_rounded;
                            tooltip = '本地儲存模式 (Free)';
                          } else if (!isCloud) {
                            iconColor = Colors.orange;
                            iconData = Icons.cloud_off_rounded;
                            tooltip = '連線中斷，切換至本地模式';
                          } else {
                            iconColor = Colors.green.shade400;
                            iconData = Icons.cloud_done_rounded;
                            tooltip = '雲端同步已開啟 (Plus/Pro)';
                          }

                          return Container(
                            margin: const EdgeInsets.only(right: 12),
                            child: Tooltip(
                              message: tooltip,
                              child: InkWell(
                                onTap: () {
                                  if (!hasCloudSupport) {
                                    _showUpgradeDialog(context, currentTier: 'free');
                                  } else if (!isCloud) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('目前網路不穩，已自動啟動本地保護機制')),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('您的資料已由雲端安全守護')),
                                    );
                                  }
                                },
                                child: Icon(iconData, size: 20, color: iconColor),
                              ),
                            ),
                          );
                        },
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

                  return GestureDetector(
                    onTap: () => AdService().watchAdForPoints(context),
                    child: Container(
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
                            Icons.pets_rounded,
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
                          const SizedBox(width: 4),
                          const Icon(Icons.add_circle_outline, size: 16, color: AppColors.primary),
                        ],
                      ),
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

  void _showUpgradeDialog(BuildContext context, {required String currentTier}) {
    final String targetTier = currentTier == 'free' ? 'Plus' : 'Pro';
    final Color tierColor = currentTier == 'free' ? Colors.blue : Colors.amber;
    final String title = '解鎖 $targetTier 方案';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: tierColor),
            const SizedBox(width: 12),
            Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentTier == 'free' 
                ? '開啟雲端備份，守護毛小孩的每一份回憶：'
                : '晉升 Pro 尊榮，享受極致 AI 體驗：', 
              style: GoogleFonts.outfit()
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(Icons.cloud_sync_rounded, currentTier == 'free' ? '雲端即時備份與同步' : '雲端最速同步優先權'),
            _buildFeatureItem(Icons.devices_rounded, '跨裝置隨時隨地存取'),
            _buildFeatureItem(Icons.auto_awesome_rounded, currentTier == 'free' ? 'AI 溝通點數加成' : '無限次 AI 寵物溝通'),
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
            child: Text('了解 $targetTier 詳情', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
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

