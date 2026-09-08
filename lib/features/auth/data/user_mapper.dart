import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/user_model.dart';

class UserMapper {
  static UserModel fromMap(Map<String, dynamic> map, String uid) => UserModel(
    uid: uid,
    email: map['email'] as String? ?? '',
    displayName: map['displayName'] as String? ?? '',
    photoUrl: (map['photoUrl'] ?? map['photoURL']) as String?,
    points: map['points'] as int? ?? 0,
    membershipTier:
        (map['membershipTier'] ?? map['membershipType']) as String? ?? 'free',
    hasCompletedOnboarding: map['hasCompletedOnboarding'] as bool? ?? false,
    createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    lastLoginAt: (map['lastLoginAt'] as Timestamp?)?.toDate(),
  );
  static Map<String, dynamic> toMap(UserModel user) => {
    'uid': user.uid,
    'email': user.email,
    'displayName': user.displayName,
    'photoUrl': user.photoUrl,
    'points': user.points,
    'membershipTier': user.membershipTier,
    'hasCompletedOnboarding': user.hasCompletedOnboarding,
    'createdAt': user.createdAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(user.createdAt!),
    'lastLoginAt': user.lastLoginAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(user.lastLoginAt!),
  };
}
