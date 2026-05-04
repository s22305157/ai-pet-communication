import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  
  // 向後相容別名 (Firebase 使用 photoURL)
  String? get photoURL => photoUrl;
  
  final int points;
  final String membershipTier;

  // 向後相容別名 (舊代碼使用 membershipType)
  String get membershipType => membershipTier;

  final bool hasCompletedOnboarding;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.points = 0,
    this.membershipTier = 'free',
    this.hasCompletedOnboarding = false,
    this.createdAt,
    this.lastLoginAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return UserModel(
      uid: id ?? map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoUrl: map['photoUrl'] ?? map['photoURL'],
      points: map['points'] ?? 0,
      membershipTier: map['membershipTier'] ?? map['membershipType'] ?? 'free',
      hasCompletedOnboarding: map['hasCompletedOnboarding'] ?? false,
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
      lastLoginAt: map['lastLoginAt'] != null ? (map['lastLoginAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'points': points,
      'membershipTier': membershipTier,
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWith({
    String? displayName,
    String? photoUrl,
    int? points,
    String? membershipTier,
    bool? hasCompletedOnboarding,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      points: points ?? this.points,
      membershipTier: membershipTier ?? this.membershipTier,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  // 將 UID 轉換為純數字顯示 (僅用於顯示)
  static String getNumericId(String? uid) {
    if (uid == null || uid.isEmpty) return '---';
    // 簡單的哈希轉換為 8 位數字
    return uid.hashCode.abs().toString().padLeft(8, '0').substring(0, 8);
  }
}
