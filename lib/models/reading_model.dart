import 'package:cloud_firestore/cloud_firestore.dart';

class ReadingModel {
  final String? id;
  final String petId;
  final String ownerId;
  
  // 溝通當下的背景快照 (防止未來寵物資料修改導致紀錄錯亂)
  final String petName;
  final String petSpecies;
  final String petBreed;
  
  // 使用者輸入
  final String userContext; // 使用者描述的情況或問題
  
  // AI 分析結果
  final String aiRawResponse;   // 原始回應
  final String petMood;         // 毛小孩當下的心情 (如：開心、焦慮)
  final String translatedVoice; // 毛小孩的心聲 (第一人稱翻譯)
  final String advice;          // 給主人的建議
  
  final DateTime timestamp;

  ReadingModel({
    this.id,
    required this.petId,
    required this.ownerId,
    required this.petName,
    required this.petSpecies,
    required this.petBreed,
    required this.userContext,
    required this.aiRawResponse,
    required this.petMood,
    required this.translatedVoice,
    required this.advice,
    required this.timestamp,
  });

  factory ReadingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReadingModel(
      id: doc.id,
      petId: data['pet_id'] ?? '',
      ownerId: data['owner_id'] ?? '',
      petName: data['pet_name'] ?? '',
      petSpecies: data['pet_species'] ?? '',
      petBreed: data['pet_breed'] ?? '',
      userContext: data['user_context'] ?? '',
      aiRawResponse: data['ai_raw_response'] ?? '',
      petMood: data['pet_mood'] ?? '',
      translatedVoice: data['translated_voice'] ?? '',
      advice: data['advice'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'pet_id': petId,
      'owner_id': ownerId,
      'pet_name': petName,
      'pet_species': petSpecies,
      'pet_breed': petBreed,
      'user_context': userContext,
      'ai_raw_response': aiRawResponse,
      'pet_mood': petMood,
      'translated_voice': translatedVoice,
      'advice': advice,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
