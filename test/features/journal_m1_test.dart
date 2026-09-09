import 'package:mocktail/mocktail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_pet_communication/features/journal/application/journal_controller.dart';
import 'package:ai_pet_communication/features/journal/data/journal_draft_store.dart';
import 'package:ai_pet_communication/features/journal/domain/journal_entry.dart';
import 'package:ai_pet_communication/features/journal/domain/journal_repository.dart';
import 'package:ai_pet_communication/features/journal/presentation/journal_editor.dart';
import 'package:ai_pet_communication/features/journal/presentation/journal_screen.dart';
import 'package:ai_pet_communication/features/journal/presentation/pilot_onboarding.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

class TestJournalRepository implements JournalRepository {
  @override
  String uid = 'owner';
  @override
  bool isCurrentSession = true;
  final calls = <String>[];
  Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)? handler;
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    calls.add(action);
    if (handler != null) return handler!(action, data);
    return switch (action) {
      'getPilotAccess' => {'enabled': true, 'invited': true, 'activated': true},
      'getJournalHome' => {
        'pet': {'id': 'pet', 'name': '小花', 'entryCount': 0, 'usedBytes': 0},
        'weekDays': 0,
      },
      'listJournalEntries' => {'items': [], 'cursor': null},
      _ => {},
    };
  }

  @override
  Future<PilotAccess> getPilotAccess() async =>
      PilotAccess.fromMap(await call('getPilotAccess'));
  @override
  Future<JournalHome> getJournalHome() async =>
      JournalHome.fromMap(await call('getJournalHome'));
  @override
  Future<JournalPage> listEntries({
    required String petId,
    String? context,
    DateTime? from,
    DateTime? to,
    JournalCursor? cursor,
  }) async => JournalPage.fromMap(
    await call('listJournalEntries', {
      'petId': petId,
      'context': ?context,
      if (from != null) 'fromMs': from.millisecondsSinceEpoch,
      if (to != null) 'toMs': to.millisecondsSinceEpoch,
      if (cursor != null) 'cursor': cursor.toMap(),
    }),
  );
  @override
  Future<void> activatePilot({required bool metricsConsent}) async {
    await call('activatePilot', {
      'consentVersion': 'journal-m1-v1',
      'metricsConsent': metricsConsent,
    });
  }

  @override
  Future<void> createPet(JournalPetInput input) async {
    await call('createJournalPet', input.toMap());
  }

  @override
  Future<void> saveEntry(JournalEntryInput input) async {
    await call('upsertJournalEntry', input.toMap());
  }

  @override
  Future<void> deleteEntry({
    required String petId,
    required String entryId,
    required int expectedRevision,
  }) async {
    await call('deleteJournalEntry', {
      'petId': petId,
      'entryId': entryId,
      'expectedRevision': expectedRevision,
    });
  }

  @override
  Future<void> deletePet(String petId) async {
    await call('deleteJournalPet', {'petId': petId});
  }

  @override
  Future<Map<String, dynamic>> exportJournal(String petId) =>
      call('exportJournal', {'petId': petId});

  @override
  Future<Uint8List> image(String mediaId) async => Uint8List(0);
  @override
  Future<String> upload(
    String petId,
    Uint8List bytes,
    String contentType,
  ) async => 'media';
}

void main() {
  testWidgets('onboarding copies a non-cat species and submits it', (
    tester,
  ) async {
    String? savedSpecies;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PilotOnboarding(
              activated: true,
              existingPets: const [(name: '小白', species: '兔')],
              onSubmit: (name, species, focus, arrivedAt, metrics) async {
                expect(name, '小白');
                expect(focus, '毛孩到家');
                savedSpecies = species;
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('小白 · 兔').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('開始我的私人日記'));
    await tester.tap(find.text('開始我的私人日記'));
    await tester.pumpAndSettle();
    expect(savedSpecies, '兔');
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  test(
    'drafts isolate accounts, serialize writes and clear only the deleted account',
    () async {
      final store = JournalDraftStore();
      await Future.wait([
        store.save('a', 'p', 'new', {'observation': 'first'}),
        store.save('a', 'p', 'new', {'observation': 'latest'}),
        store.save('b', 'p', 'new', {'observation': 'private B'}),
      ]);
      expect((await store.read('a', 'p', 'new'))!['observation'], 'latest');
      await store.clearUser('a');
      expect(await store.read('a', 'p', 'new'), isNull);
      expect((await store.read('b', 'p', 'new'))!['observation'], 'private B');
    },
  );
  test(
    'legacy plaintext draft migrates before deletion and new drafts never use preferences',
    () async {
      const key = 'journalDraft/a/p/new';
      SharedPreferences.setMockInitialValues({
        key: '{"observation":"private"}',
      });
      final store = JournalDraftStore();
      expect((await store.read('a', 'p', 'new'))!['observation'], 'private');
      expect((await SharedPreferences.getInstance()).containsKey(key), false);
      await store.save('a', 'p', 'new', {'observation': 'new private'});
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      await store.clearUser('a');
      expect(await store.read('a', 'p', 'new'), isNull);
    },
  );
  test(
    'failed encrypted migration preserves the original plaintext draft',
    () async {
      const key = 'journalDraft/a/p/new';
      SharedPreferences.setMockInitialValues({
        key: '{"observation":"retain me"}',
      });
      final storage = MockSecureStorage();
      when(
        () => storage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => null);
      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenThrow(StateError('device locked'));
      final store = JournalDraftStore(storage: storage);
      await expectLater(store.read('a', 'p', 'new'), throwsStateError);
      expect(
        (await SharedPreferences.getInstance()).getString(key),
        '{"observation":"retain me"}',
      );
    },
  );
  test('controller suppresses old session results', () async {
    final repo = TestJournalRepository();
    final pending = Completer<Map<String, dynamic>>();
    repo.handler = (action, data) => action == 'getPilotAccess'
        ? pending.future
        : Future.value({'pet': null});
    final controller = JournalController(repo);
    final load = controller.load();
    repo.isCurrentSession = false;
    pending.complete({'invited': true});
    await load;
    expect(controller.access, isNull);
    expect(controller.pet, isNull);
    controller.dispose();
  });
  test(
    'disabled access never enables writing and failed loads surface an error',
    () async {
      final repo = TestJournalRepository()
        ..handler = (action, data) async {
          if (action == 'getPilotAccess') {
            return {'enabled': false, 'invited': true, 'activated': true};
          }
          if (action == 'getJournalHome') return {'pet': null};
          throw StateError('connection failed');
        };
      final controller = JournalController(repo);
      await controller.load();
      expect(controller.canWrite, false);
      repo.handler = (_, _) async => throw StateError('connection failed');
      await controller.load();
      expect(controller.error, isNotNull);
      controller.dispose();
    },
  );

  testWidgets(
    'mobile journal layout offers private entry and no future-phase features',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = TestJournalRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: JournalScreen(repository: repo, drafts: JournalDraftStore()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('記下一件小事'), findsOneWidget);
      expect(find.text('同伴圈'), findsNothing);
      expect(find.text('小花 的相處日記'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty diary is rejected locally and failed cloud save retains the typed draft',
    (tester) async {
      final repo = TestJournalRepository()
        ..handler = (_, _) async => throw StateError('offline');
      final drafts = JournalDraftStore();
      await tester.pumpWidget(
        MaterialApp(
          home: JournalEditor(repository: repo, drafts: drafts, petId: 'pet'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('儲存到私人日記'));
      await tester.tap(find.text('儲存到私人日記'));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);
      await tester.enterText(find.byType(TextField).first, '今天第一次靠近我');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('儲存到私人日記'));
      await tester.tap(find.text('儲存到私人日記'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('upsertJournalEntry'));
      expect(
        (await drafts.read('owner', 'pet', 'new'))!['observation'],
        '今天第一次靠近我',
      );
      expect(find.text('offline'), findsOneWidget);
    },
  );

  testWidgets(
    'restored stale draft cannot silently overwrite a newer cloud revision',
    (tester) async {
      final repo = TestJournalRepository();
      final drafts = JournalDraftStore();
      final entry = JournalEntry(
        id: 'entry',
        occurredAt: DateTime.now(),
        context: '休息',
        observation: '新版本',
        action: '',
        outcome: '',
        mediaIds: [],
        revision: 2,
      );
      await drafts.save('owner', 'pet', 'entry', {
        ...entry.toInput(),
        'expectedRevision': 1,
        'observation': '舊草稿',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: JournalEditor(
            repository: repo,
            drafts: drafts,
            petId: 'pet',
            entry: entry,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '儲存到私人日記'),
      );
      expect(button.onPressed, isNull);
      expect(find.text('舊草稿'), findsOneWidget);
      expect(repo.calls, isEmpty);
    },
  );
}
