import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants.dart';
import '../../features/readings/domain/reading.dart';
import '../../features/readings/data/firestore_readings_repository.dart';

class ReadingDetailScreen extends StatefulWidget {
  final Reading? reading;
  final String petId;
  final String readingId;
  final FirebaseFirestore? firestore;

  const ReadingDetailScreen({
    super.key,
    this.reading,
    required this.petId,
    required this.readingId,
    this.firestore,
  });

  @override
  State<ReadingDetailScreen> createState() => _ReadingDetailScreenState();
}

class _ReadingDetailScreenState extends State<ReadingDetailScreen> {
  Reading? _currentReading;
  bool _isLoading = false;
  String? _errorMessage;
  late final FirestoreReadingsRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = FirestoreReadingsRepository(widget.firestore ?? FirebaseFirestore.instance);
    _currentReading = widget.reading;
    
    if (_currentReading == null) {
      _fetchReading();
    }
  }

  Future<void> _fetchReading() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reading = await _repository.getReadingById(widget.petId, widget.readingId);
      if (mounted) {
        setState(() {
          _currentReading = reading;
          if (reading == null) {
            _errorMessage = '無法讀取該則紀錄';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '載入失敗，請稍後重試';
        });
      }
    }
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
          '紀錄詳情',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null || _currentReading == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.redAccent.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? '發生錯誤',
                style: GoogleFonts.outfit(fontSize: 16, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchReading,
                icon: const Icon(Icons.refresh),
                label: const Text('重試'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final reading = _currentReading!;
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reading.title.isNotEmpty ? reading.title : 'AI 寵物溝通紀錄',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                dateFormat.format(reading.createdAt),
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (reading.source != null || reading.mood != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (reading.mood != null)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      reading.mood!,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (reading.source != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      reading.source!,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          Text(
            reading.content,
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
