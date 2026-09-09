import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_pet_communication/features/profile/presentation/points_shop_screen.dart';
import 'package:ai_pet_communication/models/user_model.dart';

UserModel member({int points = 15}) => UserModel(
  uid: 'user1',
  email: 'test@example.com',
  displayName: '測試',
  points: points,
  membershipTier: 'plus',
  subscriptionVerified: true,
  membershipEntitlements: {'plus': DateTime(2100)},
);

void main() {
  testWidgets('plus symbol opens shop and back returns to original screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: PointsBalanceButton(
              points: 15,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      PointsShopScreen(userStream: Stream.value(member())),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    expect(find.text('點數與會員方案'), findsOneWidget);
    expect(find.text('目前餘額  15 PT'), findsOneWidget);
    expect(find.text('目前會員  PLUS'), findsOneWidget);
    expect(find.text('10 點體驗包'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('15 PT'), findsOneWidget);
  });

  testWidgets(
    'plan selection changes summary without changing active membership',
    (tester) async {
      final updates = StreamController<UserModel?>();
      addTearDown(updates.close);
      await tester.pumpWidget(
        MaterialApp(home: PointsShopScreen(userStream: updates.stream)),
      );
      updates.add(member());
      await tester.pump();
      await tester.tap(find.text('會員方案'));
      await tester.pumpAndSettle();
      expect(find.text('已選擇 Plus · NT\$199／月'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('offer-pro')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('offer-pro')));
      await tester.pumpAndSettle();
      expect(find.text('已選擇 Pro · NT\$399／月'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      updates.add(member(points: 12));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('目前餘額  12 PT'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('目前會員  PLUS'), findsOneWidget);
      await tester.tap(find.text('購買點數'));
      await tester.pumpAndSettle();
      expect(find.text('已選擇 10 點體驗包 · NT\$49／一次購買'), findsOneWidget);
    },
  );

  testWidgets(
    'narrow screen with enlarged text supports free selection and rules',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: PointsShopScreen(
            userStream: Stream.value(null),
            initialOffer: 'free',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('免費方案免購買'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('點數怎麼使用？'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('點數怎麼使用？'));
      await tester.pumpAndSettle();
      expect(find.textContaining('優先使用每日贈點'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
