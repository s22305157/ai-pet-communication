import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_pet_communication/app/theme.dart';
import 'package:ai_pet_communication/app/injection.dart';
import 'package:ai_pet_communication/features/readings/domain/readings_repository.dart';
import 'package:ai_pet_communication/features/readings/domain/reading.dart';
import 'package:ai_pet_communication/features/readings/application/reading_service.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/features/readings/presentation/widgets/reading_list_tile.dart';
import 'package:ai_pet_communication/features/readings/presentation/reading_detail_screen.dart';

class PetReadingsSection extends StatefulWidget {
  final PetModel pet;
  final ReadingsRepository? readingsRepository;
  final ReadingService? readingService;

  const PetReadingsSection({
    super.key,
    required this.pet,
    this.readingsRepository,
    this.readingService,
  });

  @override
  State<PetReadingsSection> createState() => _PetReadingsSectionState();
}

class _PetReadingsSectionState extends State<PetReadingsSection> {
  late final ReadingsRepository _readingsRepository =
      widget.readingsRepository ?? getIt<ReadingsRepository>();
  late final ReadingService _readingService =
      widget.readingService ?? getIt<ReadingService>();

  Stream<List<Reading>>? _readingsStream;

  @override
  void initState() {
    super.initState();
    _readingsStream = _readingsRepository.watchReadingsByPetId(
      widget.pet.petId,
    );
  }

  @override
  void didUpdateWidget(covariant PetReadingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pet.petId != oldWidget.pet.petId ||
        widget.pet.ownerId != oldWidget.pet.ownerId) {
      setState(() {
        _readingsStream = _readingsRepository.watchReadingsByPetId(
          widget.pet.petId,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppStyles.borderRadius),
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 48,
                        color: AppColors.secondary.withValues(alpha: 0.5),
                      ),
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
                        '未來會在這裡顯示您與 ${widget.pet.name} 的對話',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
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
                            petId: widget.pet.petId,
                            readingId: reading.id,
                            readingsRepository: _readingsRepository,
                          ),
                        ),
                      );
                    },
                    onDelete: () async {
                      await _readingService.deleteReading(
                        widget.pet.petId,
                        reading.id,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('紀錄已刪除')));
                      }
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
