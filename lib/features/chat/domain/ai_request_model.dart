// lib/features/chat/domain/ai_request_model.dart
// ============================================================
// PAWLINK - AI 請求模型 (Domain Model)
// ============================================================

import '../application/media_payload.dart';

/// AI 寵物溝通請求模型
class AiRequestModel {
  /// 飼主前測資料
  final OwnerProfile ownerProfile;

  /// 毛孩檔案
  final PetProfile petProfile;

  /// 諮詢素材 (5000 字以內)
  final String story;

  /// 提問清單 (1~5 題)
  final List<String> questions;

  /// 輸入模式 (free, pro)
  final String inputMode;

  /// 媒體資料 (可為 null)
  final MediaPayload? media;

  const AiRequestModel({
    required this.ownerProfile,
    required this.petProfile,
    required this.story,
    required this.questions,
    required this.inputMode,
    this.media,
  });

  /// 轉換為 Map，符合 Schema 要求
  Map<String, dynamic> toMap() {
    return {
      'ownerProfile': ownerProfile.toMap(),
      'petProfile': petProfile.toMap(),
      'story': story,
      'questions': questions,
      'inputMode': inputMode,
      'media': media?.toJson(),
    };
  }
}

/// 飼主畫像
class OwnerProfile {
  final String experienceLevel;
  final String careStyle;
  final String emotionStyle;
  final String dailyRoutine;
  final String mainConcern;

  const OwnerProfile({
    required this.experienceLevel,
    required this.careStyle,
    required this.emotionStyle,
    required this.dailyRoutine,
    required this.mainConcern,
  });

  Map<String, dynamic> toMap() {
    return {
      'experienceLevel': experienceLevel,
      'careStyle': careStyle,
      'emotionStyle': emotionStyle,
      'dailyRoutine': dailyRoutine,
      'mainConcern': mainConcern,
    };
  }
}

/// 毛孩檔案
class PetProfile {
  final String name;
  final String species;
  final String breed;
  final double age;
  final String coatColor;
  final List<String> personalityTraits;

  const PetProfile({
    required this.name,
    required this.species,
    required this.breed,
    required this.age,
    required this.coatColor,
    required this.personalityTraits,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'species': species,
      'breed': breed,
      'age': age,
      'coatColor': coatColor,
      'personalityTraits': personalityTraits,
    };
  }
}
