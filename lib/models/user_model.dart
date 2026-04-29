class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoURL;
  final int points;
  final String membershipType;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoURL,
    this.points = 0,
    this.membershipType = 'free',
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'display_name': displayName,
      'photo_url': photoURL,
      'points': points,
      'membership_type': membershipType,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['display_name'] ?? '',
      photoURL: map['photo_url'],
      points: (map['points'] ?? 0).toInt(),
      membershipType: map['membership_type'] ?? 'free',
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    int? points,
    String? membershipType,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      points: points ?? this.points,
      membershipType: membershipType ?? this.membershipType,
    );
  }
}
