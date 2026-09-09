import 'package:ai_pet_communication/models/user_model.dart';
import 'package:ai_pet_communication/features/auth/data/user_mapper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('expiry is exclusive and falls back from Pro to remaining Plus', () {
    final user = UserModel(
      uid: 'a',
      email: '',
      displayName: '',
      membershipTier: 'pro',
      subscriptionVerified: true,
      membershipEntitlements: {
        'pro': DateTime.utc(2030),
        'plus': DateTime.utc(2031),
      },
    );
    expect(user.tierAt(DateTime.utc(2029)), 'pro');
    expect(user.tierAt(DateTime.utc(2030)), 'plus');
    expect(user.tierAt(DateTime.utc(2031)), 'free');
    expect(user.canReadCloudArchive, isTrue);
    expect(
      user.copyWith(displayName: 'updated').tierAt(DateTime.utc(2030)),
      'plus',
    );
  });

  test('legacy paid tier has archive access but cannot grant paid rights', () {
    final user = UserMapper.fromMap({'membershipTier': 'pro'}, 'a');
    expect(user.membershipTier, 'free');
    expect(user.canReadCloudArchive, isTrue);
    expect(
      UserModel(uid: 'a', email: '', displayName: '').canReadCloudArchive,
      isFalse,
    );
  });

  test(
    'only verified timestamp entitlements are accepted; mapper does not write server fields',
    () {
      final user = UserMapper.fromMap({
        'membershipTier': 'pro',
        'subscriptionVerified': true,
        'membershipEntitlements': {
          'plus': Timestamp.fromDate(DateTime.utc(2100)),
          'pro': 'forged',
        },
        'hadPaidMembership': true,
        'subscriptionWillRenew': false,
      }, 'a');
      expect(user.membershipTier, 'plus');
      expect(user.subscriptionWillRenew, isFalse);
      final data = UserMapper.toMap(user);
      expect(data.containsKey('subscriptionVerified'), isFalse);
      expect(data.containsKey('membershipEntitlements'), isFalse);
    },
  );
}
