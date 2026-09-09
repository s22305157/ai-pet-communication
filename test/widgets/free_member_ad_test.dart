import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_pet_communication/models/user_model.dart';
import 'package:ai_pet_communication/widgets/free_member_ad.dart';

void main() {
  UserModel user({
    String tier = 'free',
    bool verified = true,
    String uid = 'u',
  }) => UserModel(
    uid: uid,
    email: 'test@example.com',
    displayName: 'Test',
    membershipTier: tier,
    subscriptionVerified: verified,
    membershipEntitlements: tier == 'free'
        ? {}
        : {tier: DateTime.now().add(const Duration(days: 1))},
  );

  testWidgets(
    'unknown, paid, signed-out and errored accounts never show ads; updates are live',
    (tester) async {
      final users = StreamController<UserModel?>();
      addTearDown(users.close);
      var clicks = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: FreeMemberAd(
              users: users.stream,
              uid: 'u',
              onViewPlans: () => clicks++,
            ),
          ),
        ),
      );
      expect(find.text('查看方案'), findsNothing);
      users.add(user());
      await tester.pumpAndSettle();
      expect(find.text('廣告・PAWLINK 自家推廣'), findsOneWidget);
      await tester.tap(find.text('查看方案'));
      expect(clicks, 1);
      for (final tier in ['plus', 'pro']) {
        users.add(user(tier: tier));
        await tester.pumpAndSettle();
        expect(find.text('查看方案'), findsNothing);
      }
      users.add(user(tier: 'pro', verified: false));
      await tester.pumpAndSettle();
      expect(find.text('查看方案'), findsOneWidget);
      users.add(user(uid: 'different-account'));
      await tester.pumpAndSettle();
      expect(find.text('查看方案'), findsNothing);
      users.add(null);
      await tester.pumpAndSettle();
      expect(find.text('查看方案'), findsNothing);
      users.add(user());
      await tester.pumpAndSettle();
      users.addError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('查看方案'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'expired membership shows promotion and narrow layout supports large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final expired = UserModel(
        uid: 'u',
        email: '',
        displayName: '',
        membershipTier: 'plus',
        subscriptionVerified: true,
        membershipEntitlements: {
          'plus': DateTime.now().subtract(const Duration(seconds: 1)),
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            bottomNavigationBar: FreeMemberAd(
              users: Stream.value(expired),
              uid: 'u',
              onViewPlans: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('查看方案'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
