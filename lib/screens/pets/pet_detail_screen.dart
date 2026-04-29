import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../constants.dart';
import '../../models/pet_model.dart';
import '../../services/pet_service.dart';
import '../../features/readings/data/firestore_readings_repository.dart';
import '../../features/readings/domain/reading.dart';
import '../../features/readings/application/reading_service.dart';
import 'widgets/reading_list_tile.dart';
import 'reading_detail_screen.dart';
import 'pet_form_sheet.dart';
import '../../services/error_service.dart';
import '../../services/auth_service.dart';

class PetDetailScreen extends StatefulWidget {
  final PetModel pet;
  final FirebaseFirestore? firestore;

  const PetDetailScreen({super.key, required this.pet, this.firestore});

  @override
  State<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends State<PetDetailScreen> {
  late PetModel _currentPet;
  late final PetService _petService = PetService();
  late final FirestoreReadingsRepository _readingsRepository = FirestoreReadingsRepository(widget.firestore ?? FirebaseFirestore.instance);
  final ImagePicker _picker = ImagePicker();

  bool _isUploading = false;

  /// 圖片 bytes，優先用於顯示，避免 CORS 問題
  /// - 初次進入頁面時：從 URL 抓取（_loadAvatarFromUrl）
  /// - 用戶選取新圖片後：直接使用本機 bytes
  Uint8List? _avatarBytes;
  bool _isLoadingAvatar = false;
  Stream<List<Reading>>? _readingsStream;

  @override
  void initState() {
    super.initState();
    _currentPet = widget.pet;
    _readingsStream = _readingsRepository.watchReadingsByPetId(_currentPet.petId!);
    // 若已有頭像 URL，進入頁面時先用 http 抓成 bytes
    if (_currentPet.avatarUrl.isNotEmpty) {
      _loadAvatarFromUrl(_currentPet.avatarUrl);
    }
  }

  // ── 用 http 把遠端圖片抓成 bytes（繞過 CORS 限制）──────────────────────
  Future<void> _loadAvatarFromUrl(String url) async {
    setState(() => _isLoadingAvatar = true);
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _avatarBytes = response.bodyBytes;
          _isLoadingAvatar = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingAvatar = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAvatar = false);
    }
  }

  // ── 選取並上傳新頭像 ─────────────────────────────────────────────────────
  Future<void> _pickAndUploadAvatar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (file == null) return;

    // 立即讀取 bytes → 先更新 UI 預覽
    final Uint8List bytes = await file.readAsBytes();
    setState(() {
      _avatarBytes = bytes;
      _isUploading = true;
    });

    try {
      final imageId = const Uuid().v4();

      // 1. 上傳到 Firebase Storage
      final url = await _petService.uploadPetAvatar(uid, imageId, bytes);

      // 2. 更新 Firestore
      final updatedPet = _currentPet.copyWith(avatarUrl: url);
      await _petService.updatePet(updatedPet.petId!, updatedPet);

      if (mounted) {
        setState(() {
          _currentPet = updatedPet;
          _isUploading = false;
          // _avatarBytes 已更新，不需再 reload
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('頭像更新成功！'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('頭像上傳失敗: ${ErrorService.getErrorMessage(e)}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ── UI Helpers ───────────────────────────────────────────────────────────
  Widget _buildAvatarContent() {
    if (_isUploading || _isLoadingAvatar) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      );
    }
    if (_avatarBytes != null) {
      return Image.memory(
        _avatarBytes!,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
      );
    }
    return _buildInitialPlaceholder();
  }

  Widget _buildInitialPlaceholder() {
    return Center(
      child: Text(
        _currentPet.name.isNotEmpty ? _currentPet.name[0] : '?',
        style: GoogleFonts.outfit(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '-',
              style: GoogleFonts.outfit(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
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
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, size: 28),
            onPressed: () async {
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => PetFormSheet(existingPet: _currentPet),
              );
              // 表單關閉後，從 Firestore 重新獲取最新資料並刷新 UI
              final doc = await FirebaseFirestore.instance.collection('pets').doc(_currentPet.petId).get();
              if (doc.exists && mounted) {
                setState(() {
                  _currentPet = PetModel.fromDoc(doc);
                });
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // ── Avatar Section ──
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: (_isUploading || _isLoadingAvatar)
                        ? null
                        : _pickAndUploadAvatar,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: ClipOval(child: _buildAvatarContent()),
                    ),
                  ),
                  // 相機按鈕
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: (_isUploading || _isLoadingAvatar)
                          ? null
                          : _pickAndUploadAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
                '${_currentPet.species} ${_currentPet.breed.isNotEmpty ? '· ${_currentPet.breed}' : ''}',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),

            const SizedBox(height: 32),

            // ── Info Card ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppStyles.borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('性別', _currentPet.gender, Icons.pets),
                  _buildInfoRow('生日', _currentPet.birthday, Icons.cake),
                  _buildInfoRow('毛色', _currentPet.color, Icons.palette_outlined),
                  _buildInfoRow('體重', '${_currentPet.weight} kg', Icons.monitor_weight_outlined),
                  const Divider(height: 24),
                  _buildInfoRow('個性', _currentPet.personality, Icons.favorite),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── 溝通紀錄區（Placeholder）──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history, color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Text(
                        '溝通紀錄',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<Reading>>(
                    stream: _readingsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: CircularProgressIndicator(color: AppColors.primary),
                          ),
                        );
                      }
                      
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            '無法載入紀錄',
                            style: GoogleFonts.outfit(color: Colors.redAccent),
                          ),
                        );
                      }

                      final readings = snapshot.data ?? [];
                      
                      if (readings.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(AppStyles.borderRadius),
                            border: Border.all(
                                color: AppColors.secondary.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.chat_bubble_outline,
                                  size: 48,
                                  color: AppColors.secondary.withOpacity(0.5)),
                              const SizedBox(height: 12),
                              Text(
                                '尚無溝通紀錄',
                                style: GoogleFonts.outfit(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '未來會在這裡顯示您與 ${_currentPet.name} 的對話',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: AppColors.textSecondary.withOpacity(0.7),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: readings.length,
                        itemBuilder: (context, index) {
                          final reading = readings[index];
                          return ReadingListTile(
                            reading: reading,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ReadingDetailScreen(
                                    reading: reading,
                                    petId: _currentPet.petId!,
                                    readingId: reading.id,
                                    firestore: widget.firestore,
                                  ),
                                ),
                              );
                            },
                            onDelete: () async {
                              final readingService = ReadingService(
                                FirestoreReadingsRepository(widget.firestore ?? FirebaseFirestore.instance),
                              );
                              await readingService.deleteReading(_currentPet.petId!, reading.id);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('紀錄已刪除')),
                                );
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
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
    final authService = AuthService();
    final user = await authService.getUserData();
    
    if (user == null) return;

    final isPro = user.membershipType == 'pro' || user.membershipType == 'plus';
    
    if (isPro) {
      // Pro 用戶直接進入
      _navigateToAI(context);
    } else if (user.points > 0) {
      // Free 用戶且有點數：提示並扣點 (扣點邏輯應在 AI 服務中執行)
      _showPointConsumptionDialog(context);
    } else {
      // 無點數：顯示升級彈窗
      _showUpgradeDialog(context);
    }
  }

  void _navigateToAI(BuildContext context) {
    // TODO: 導向 AI 溝通介面
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('即將開啟 AI 寵物溝通介面...')),
    );
  }

  void _showPointConsumptionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('開始溝通'),
        content: const Text('本次溝通將消耗 1 PT 點數。確認開始嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToAI(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('確認', style: TextStyle(color: Colors.white)),
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
            Text('點數不足', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('升級至 Pro 方案即可享受無限次 AI 溝通，或購買點數繼續使用。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍後再說'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('了解 Pro 方案', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
