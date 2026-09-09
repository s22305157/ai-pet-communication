class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;

  // 向後相容別名 (Firebase 使用 photoURL)
  String? get photoURL => photoUrl;

  final int points;
  final String storedMembershipTier;
  final bool subscriptionVerified;
  final Map<String, DateTime> membershipEntitlements;
  final bool hadPaidMembership;
  final bool subscriptionWillRenew;

  String tierAt(DateTime now) {
    if (!subscriptionVerified) return 'free';
    for (final tier in ['pro', 'plus']) {
      if (membershipEntitlements[tier]?.isAfter(now) ?? false) return tier;
    }
    return 'free';
  }

  String get membershipTier => tierAt(DateTime.now());
  DateTime? get membershipExpiresAt => membershipEntitlements[membershipTier];
  bool get canReadCloudArchive =>
      hadPaidMembership ||
      storedMembershipTier == 'plus' ||
      storedMembershipTier == 'pro';

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
    String membershipTier = 'free',
    this.subscriptionVerified = false,
    this.membershipEntitlements = const {},
    this.hadPaidMembership = false,
    this.subscriptionWillRenew = false,
    this.hasCompletedOnboarding = false,
    this.createdAt,
    this.lastLoginAt,
  }) : storedMembershipTier = membershipTier;

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
      membershipTier: membershipTier ?? storedMembershipTier,
      subscriptionVerified: subscriptionVerified,
      membershipEntitlements: membershipEntitlements,
      hadPaidMembership: hadPaidMembership,
      subscriptionWillRenew: subscriptionWillRenew,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
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
