import 'dart:async';
import 'dart:convert';
import 'package:ai_pet_communication/features/pilot/domain/pilot_request.dart';
import 'package:ai_pet_communication/features/pilot/data/pilot_wire_mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:ai_pet_communication/features/pilot/domain/pilot_repository.dart';
import 'package:ai_pet_communication/features/pilot/application/pilot_controller.dart';
import 'package:ai_pet_communication/features/weekly_review/presentation/weekly_review_screen.dart';
import 'package:ai_pet_communication/features/community/presentation/community_screen.dart';
import 'package:ai_pet_communication/features/community/presentation/community_share_screen.dart';
import 'package:ai_pet_communication/features/pilot/presentation/pilot_notifications_screen.dart';
import 'package:ai_pet_communication/features/journal/domain/journal_entry.dart';
import 'package:ai_pet_communication/app/flutter_pilot_routes.dart';

class PilotFake implements PilotRepository {
  @override
  String requestKey(PilotRequest<void> request) {
    final (name, values) = encodePilotRequest(request);
    return jsonEncode([name, values]);
  }

  @override
  Future<T> execute<T>(PilotRequest<T> request, {String? operationId}) async {
    final (name, values) = encodePilotRequest(request);
    return decodePilotResponse(
      request,
      await call(name, {...values, 'operationId': ?operationId}),
    );
  }

  @override
  String uid = 'a';
  @override
  bool isCurrentSession = true;
  final sessions = StreamController<bool>.broadcast(sync: true);
  final calls = <(String, Map<String, dynamic>)>[];
  Future<Map<String, dynamic>> Function(String, Map<String, dynamic>) handler =
      (_, _) async => {};
  @override
  Stream<bool> get sessionChanges => sessions.stream;
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    calls.add((name, Map<String, dynamic>.from(data)));
    return handler(name, data);
  }

  void logout() {
    isCurrentSession = false;
    sessions.add(false);
  }
}

Map<String, dynamic> review({String status = 'ready'}) => {
  'status': status,
  'week': '2026-09-07',
  'stats': {'days': 3, 'textDays': 3, 'entries': 4},
  'attempts': 1,
  'canGenerate': true,
  'analysisEnabled': true,
  'trialEndsAtMs': 1790000000000,
  // A stale payload must still stay hidden when the status says invalidated.
  'result': {
    'happenings': [
      {
        'text': '主人記錄了日常',
        'entryIds': ['entry123'],
      },
    ],
    'observations': [
      {
        'text': '可能需要繼續觀察',
        'entryIds': ['entry123'],
      },
    ],
    'tips': [],
    'petVoice': '陪你一起待一下。',
  },
};
void main() {
  test(
    'controller keeps ambiguous retry operation IDs and clears state on account changes',
    () async {
      final repo = PilotFake();
      var failed = true;
      repo.handler = (_, _) async {
        if (failed) {
          throw FirebaseFunctionsException(
            code: 'unavailable',
            message: '暫時無法使用',
          );
        }
        return {};
      };
      final c = PilotController(repo, () async => {'private': '甲的資料'});
      await c.load();
      expect(await c.submit(const EncourageCommunityPost(postId: 'p')), isFalse);
      failed = false;
      expect(await c.submit(const EncourageCommunityPost(postId: 'p')), isTrue);
      expect(repo.calls[0].$2['operationId'], repo.calls[1].$2['operationId']);
      repo.logout();
      expect(c.data, isEmpty);
      expect(c.expired, isTrue);
      c.dispose();
      await repo.sessions.close();
    },
  );
  test(
    'controller rejects delayed results after session invalidation and clears inaccessible content',
    () async {
      final repo = PilotFake(), response = Completer<Map<String, dynamic>>();
      final c = PilotController(repo, () => response.future);
      final loading = c.load();
      repo.logout();
      response.complete({'private': '甲的資料'});
      await loading;
      expect(c.data, isEmpty);
      c.dispose();
      await repo.sessions.close();
      final second = PilotFake();
      second.handler = (_, _) async => throw FirebaseFunctionsException(
        code: 'permission-denied',
        message: '權限已撤銷',
      );
      final d = PilotController(second, () async => {'post': '不可再看'});
      await d.load();
      await d.mutate('encourageCommunityPost', {'postId': 'p'});
      expect(d.data, isEmpty);
      d.dispose();
      await second.sessions.close();
    },
  );
  testWidgets(
    '390px review renders source links and labels creative voice with no overflow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = PilotFake();
      repo.handler = (name, _) async => name == 'getWeeklyReview'
          ? review()
          : name == 'getWeeklyReviewSource'
          ? {
              'context': '休息',
              'observation': '主人留下的確切文字',
              'action': '',
              'outcome': '',
            }
          : {};
      await tester.pumpWidget(
        MaterialApp(
          home: WeeklyReviewScreen(
            repository: repo,
            petId: 'pet',
            initialWeek: '2026-09-07',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('原始紀錄 entry1').first);
      await tester.tap(find.text('原始紀錄 entry1').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('主人留下的確切文字'), findsOneWidget);
      await tester.tap(find.text('關閉'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('毛孩小語 · AI 創作'));
      expect(find.text('陪你一起待一下。'), findsNothing);
      await tester.tap(find.text('毛孩小語 · AI 創作'));
      await tester.pumpAndSettle();
      expect(find.text('陪你一起待一下。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'invalidated review never renders stale AI and opt-in requires the consent dialog',
    (tester) async {
      final repo = PilotFake();
      repo.handler = (name, _) async => name == 'getWeeklyReview'
          ? {...review(status: 'invalidated'), 'analysisEnabled': false}
          : {};
      await tester.pumpWidget(
        MaterialApp(
          home: WeeklyReviewScreen(repository: repo, petId: 'pet'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('主人記錄了日常'), findsNothing);
      expect(find.textContaining('舊回顧已隱藏'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('啟用 AI 日記分析'), findsOneWidget);
      expect(repo.calls.where((c) => c.$1 == 'setReviewPreference'), isEmpty);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(repo.calls.where((c) => c.$1 == 'setReviewPreference'), isEmpty);
    },
  );
  testWidgets(
    'share requires preview and confirmation; request only includes edited text and selected media',
    (tester) async {
      final repo = PilotFake();
      repo.handler = (_, _) async => {
        'communityEnabled': true,
        'communityWriteEnabled': true,
      };
      final e = JournalEntry(
        id: 'entry',
        occurredAt: DateTime(2026, 9, 7),
        context: '休息',
        observation: '私人觀察',
        action: '',
        outcome: '',
        mediaIds: const [],
        revision: 1,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityShareScreen(
            repository: repo,
            sourceImageBuilder: (_) => const SizedBox.shrink(),
            entry: e,
            petId: 'pet',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, '要分享的文字（可刪減、修改）'),
        '只分享這段',
      );
      await tester.ensureVisible(find.text('預覽分享內容'));
      await tester.tap(find.text('預覽分享內容'));
      await tester.pumpAndSettle();
      expect(repo.calls.where((c) => c.$1 == 'publishCommunityPost'), isEmpty);
      expect(find.text('只分享這段'), findsOneWidget);
      await tester.ensureVisible(find.text('確認發布到受邀同伴圈'));
      await tester.tap(find.text('確認發布到受邀同伴圈'));
      await tester.pumpAndSettle();
      final payload = repo.calls
          .singleWhere((c) => c.$1 == 'publishCommunityPost')
          .$2;
      expect(payload['confirmed'], isTrue);
      expect(payload['text'], '只分享這段');
      expect(payload['mediaIds'], isEmpty);
      expect(payload.containsKey('authorId'), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'community list uses real empty state and removes content immediately on logout',
    (tester) async {
      final repo = PilotFake();
      repo.handler = (_, _) async => {
        'items': [
          {
            'id': 'p',
            'alias': '同伴甲',
            'text': '甲的貼文',
            'topic': '毛孩到家',
            'status': 'published',
            'revision': 1,
            'createdAtMs': 1790000000000,
            'mediaIds': [],
            'commentCount': 0,
            'encouragementCount': 0,
          },
        ],
        'cursor': null,
      };
      await tester.pumpWidget(
        MaterialApp(home: CommunityScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      expect(find.text('甲的貼文'), findsOneWidget);
      repo.logout();
      await tester.pumpAndSettle();
      expect(find.text('甲的貼文'), findsNothing);
    },
  );
  testWidgets(
    'notifications show merged encouragement counts and acknowledgement is sent',
    (tester) async {
      final repo = PilotFake();
      repo.handler = (name, _) async => name == 'listPilotNotifications'
          ? {
              'items': [
                {
                  'id': 'n',
                  'type': 'moderation',
                  'read': false,
                  'message': '檢舉已处理',
                },
                {'id': 'e', 'type': 'encouragement', 'count': 2, 'read': false},
              ],
              'cursor': null,
            }
          : {};
      await tester.pumpWidget(
        MaterialApp(
          home: PilotNotificationsScreen(
            repository: repo,
            routes: FlutterPilotRoutes(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 位同伴給你鼓勵'), findsOneWidget);
      await tester.tap(find.text('檢舉已处理'));
      await tester.pumpAndSettle();
      expect(
        repo.calls.where((c) => c.$1 == 'markPilotNotificationRead').length,
        1,
      );
    },
  );
}
