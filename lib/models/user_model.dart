class UserModel {
  static String getNumericId(String? uid) {
    if (uid == null || uid.isEmpty) return '-';
    // Use a deterministic hash to create a numeric ID (Consistent with ProfileScreen)
    int hash = 0;
    for (int i = 0; i < uid.length; i++) {
      hash = uid.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return hash.abs().toString().padLeft(10, '0').substring(0, 10);
  }

  final String uid;
  final String email;
  final String displayName;
  final String? photoURL;
  final int points;
  final String membershipType;
  final bool hasCompletedOnboarding;
  final Map<String, dynamic>? onboardingAnswers;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoURL,
    this.points = 0,
    this.membershipType = 'free',
    this.hasCompletedOnboarding = false,
    this.onboardingAnswers,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'display_name': displayName,
      'photo_url': photoURL,
      'points': points,
      'membership_type': membershipType,
      'has_completed_onboarding': hasCompletedOnboarding,
      'onboarding_answers': onboardingAnswers,
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
      hasCompletedOnboarding: map['has_completed_onboarding'] ?? false,
      onboardingAnswers: map['onboarding_answers'] as Map<String, dynamic>?,
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    int? points,
    String? membershipType,
    bool? hasCompletedOnboarding,
    Map<String, dynamic>? onboardingAnswers,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      points: points ?? this.points,
      membershipType: membershipType ?? this.membershipType,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      onboardingAnswers: onboardingAnswers ?? this.onboardingAnswers,
    );
  }
}
