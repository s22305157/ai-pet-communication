import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoURL;
  final String membershipType; // free, pro, premium
  final int points;
  final int totalReadings;
  final DateTime? lastResetDate;
  final String clientVersion;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoURL,
    this.membershipType = 'free',
    this.points = 1,
    this.totalReadings = 0,
    this.lastResetDate,
    this.clientVersion = '0.0.2',
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['display_name'] ?? '',
      photoURL: data['photo_url'],
      membershipType: data['membership_type'] ?? 'free',
      points: data['points'] ?? 0,
      totalReadings: data['total_readings'] ?? 0,
      lastResetDate: (data['last_reset_date'] as Timestamp?)?.toDate(),
      clientVersion: data['client_version'] ?? '1.0.0',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'display_name': displayName,
      'photo_url': photoURL,
      'membership_type': membershipType,
      'points': points,
      'total_readings': totalReadings,
      'last_reset_date': lastResetDate != null ? Timestamp.fromDate(lastResetDate!) : FieldValue.serverTimestamp(),
      'client_version': clientVersion,
    };
  }
}
