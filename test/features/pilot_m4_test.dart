import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:ai_pet_communication/features/pilot/data/pilot_wire_mapper.dart';
import 'package:ai_pet_communication/features/pilot/domain/pilot_request.dart';
import 'package:ai_pet_communication/features/pilot/presentation/pilot_interest_screen.dart';
import 'package:ai_pet_communication/features/pilot/presentation/pilot_metrics_screen.dart';
import 'package:ai_pet_communication/features/pilot/presentation/pilot_cost_screen.dart';
import 'package:ai_pet_communication/features/pilot/presentation/pilot_admin_screen.dart';
import 'journal_m23_test.dart' show PilotFake;

Map<String, dynamic> ratio(int numerator, int denominator, [int pending = 0]) =>
    {'numerator': numerator, 'denominator': denominator, 'pending': pending};
Map<String, dynamic> report({bool truncated = false}) => {
  'truncated': truncated,
  'metrics': {
    'fromMs': 1780000000000,
    'toMs': 1787776000000,
    'measuredParticipants': 2,
    'activation': ratio(1, 2),
    'retention': ratio(0, 0, 2),
    'reviewViews': ratio(1, 1),
    'communityResponses': ratio(0, 0),
    'upgradeInterest': ratio(1, 2),
  },
  'costs': {'recordedDays': 0},
};
void main() {
  testWidgets(
    'M4 ordinary users cannot see cost forms or cost entry points even on a direct route',
    (tester) async {
      final repo = PilotFake();
      addTearDown(repo.sessions.close);
      repo.handler = (_, _) async => throw FirebaseFunctionsException(
        code: 'permission-denied',
        message: '需要試營運管理權限',
      );
      await tester.pumpWidget(
        MaterialApp(home: PilotAdminScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      expect(find.text('查看試營運成效與成本'), findsNothing);
      await tester.pumpWidget(
        MaterialApp(home: PilotCostScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('儲存當日總額'), findsNothing);
    },
  );
  test('M4 mapper uses typed requests and discards truncated percentages', () {
    final (name, values) = encodePilotRequest(const SetPilotInterest(true));
    expect(name, 'setPilotInterest');
    expect(values, {'interested': true, 'priceVersion': 'pilot-twd199-v1'});
    final value = decodePilotResponse(const GetPilotMetrics(), report());
    expect(value.metrics!.retention.rate, isNull);
    expect(value.metrics!.activation.rate, .5);
    expect(
      decodePilotResponse(
        const GetPilotMetrics(),
        report(truncated: true),
      ).metrics,
      isNull,
    );
  });
  for (final width in [390.0, 1200.0]) {
    testWidgets('M4 price and cancellable preference fit width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = PilotFake();
      addTearDown(repo.sessions.close);
      var interested = false;
      repo.handler = (name, data) async {
        if (name == 'setPilotInterest') interested = data['interested'] == true;
        return {
          'interested': interested,
          'metricsConsent': false,
          'canExpressInterest': true,
        };
      };
      await tester.pumpWidget(
        MaterialApp(home: PilotInterestScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      expect(find.text('預計 NT\$199／月，尚未開放購買。'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('每日成本與管理時間'), findsNothing);
      await tester.tap(find.byType(SwitchListTile).first);
      await tester.pumpAndSettle();
      expect(interested, isTrue);
      expect(repo.calls.where((c) => c.$1 == 'markPilotPriceViewed'), isEmpty);
      await tester.tap(find.byType(SwitchListTile).first);
      await tester.pumpAndSettle();
      expect(interested, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'M4 measurement runs after price appears and never blocks the preference page',
    (tester) async {
      final repo = PilotFake();
      addTearDown(repo.sessions.close);
      repo.handler = (name, _) async {
        if (name == 'markPilotPriceViewed') throw StateError('offline');
        return {'metricsConsent': true, 'canExpressInterest': true};
      };
      await tester.pumpWidget(
        MaterialApp(home: PilotInterestScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      expect(find.text('預計 NT\$199／月，尚未開放購買。'), findsOneWidget);
      expect(repo.calls.where((c) => c.$1 == 'markPilotPriceViewed').length, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'M4 account switch discards a delayed preference response and clears the screen',
    (tester) async {
      final repo = PilotFake();
      addTearDown(repo.sessions.close);
      final pending = Completer<Map<String, dynamic>>();
      repo.handler = (_, _) => pending.future;
      await tester.pumpWidget(
        MaterialApp(home: PilotInterestScreen(repository: repo)),
      );
      await tester.pump();
      repo.logout();
      await tester.pump();
      pending.complete({
        'interested': true,
        'metricsConsent': true,
        'canExpressInterest': true,
      });
      await tester.pumpAndSettle();
      expect(find.text('請返回首頁重新登入'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(repo.calls.where((c) => c.$1 == 'markPilotPriceViewed'), isEmpty);
    },
  );
  testWidgets(
    'M4 expired eligibility permits cancellation and pending cleanup disables reconsent',
    (tester) async {
      final repo = PilotFake();
      addTearDown(repo.sessions.close);
      repo.handler = (_, _) async => {
        'interested': true,
        'canExpressInterest': false,
        'metricsConsent': false,
        'cleanupPending': true,
      };
      await tester.pumpWidget(
        MaterialApp(home: PilotInterestScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      final switches = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      expect(switches.first.onChanged, isNotNull);
      expect(switches.last.onChanged, isNull);
    },
  );
  testWidgets(
    'M4 phone dashboard distinguishes pending cohorts and missing costs',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = PilotFake();
      addTearDown(repo.sessions.close);
      repo.handler = (_, _) async => report();
      await tester.pumpWidget(
        MaterialApp(home: PilotMetricsScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      expect(find.text('觀察中 2'), findsOneWidget);
      expect(find.text('50.0% · 1/2'), findsWidgets);
      await tester.scrollUntilVisible(find.text('尚未登錄成本與用量。'), 250);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'M4 cost editor rejects negative or fractional counts and preserves server revision',
    (tester) async {
      final repo = PilotFake();
      addTearDown(repo.sessions.close);
      repo.handler = (_, _) async => {
        'revision': 3,
        'modelTwd': 10,
        'storageTwd': 2,
        'requests': 20,
        'minutes': 5,
      };
      await tester.pumpWidget(
        MaterialApp(home: PilotCostScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(2), '1.5');
      await tester.ensureVisible(find.text('儲存當日總額'));
      await tester.tap(find.text('儲存當日總額'));
      await tester.pumpAndSettle();
      expect(find.text('請輸入有效的非負數值'), findsOneWidget);
      expect(repo.calls.where((c) => c.$1 == 'adminSetPilotCost'), isEmpty);
      await tester.enterText(find.byType(TextFormField).at(2), '21');
      await tester.tap(find.text('儲存當日總額'));
      await tester.pumpAndSettle();
      final sent = repo.calls
          .singleWhere((c) => c.$1 == 'adminSetPilotCost')
          .$2;
      expect(sent['expectedRevision'], 3);
      expect(sent['requests'], 21);
    },
  );
}
