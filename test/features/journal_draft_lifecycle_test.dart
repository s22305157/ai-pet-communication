import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_pet_communication/features/journal/application/journal_editor_controller.dart';
import 'package:ai_pet_communication/features/journal/data/journal_draft_store.dart';
import 'package:ai_pet_communication/features/journal/domain/journal_repository.dart';

class _Storage extends Mock implements FlutterSecureStorage {}

class _Repository extends Mock implements JournalRepository {}

class _Input extends Fake implements JournalEntryInput {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repository repository;
  late JournalDraftStore drafts;
  late Completer<void> firstWriteStarted, releaseFirstWrite;
  late List<JournalEditorController> editors;
  late Map<String, String> values;

  JournalEditorController editor() {
    final result = JournalEditorController(
      repository: repository,
      drafts: drafts,
      petId: 'pet',
    );
    editors.add(result);
    return result;
  }

  Future<void> pendingChanges(JournalEditorController current) async {
    await current.restore();
    current.changed(observation: 'first snapshot', action: '', outcome: '');
    await firstWriteStarted.future;
    current.changed(observation: 'last snapshot', action: '', outcome: '');
  }

  setUpAll(() => registerFallbackValue(_Input()));
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    values = {};
    editors = [];
    firstWriteStarted = Completer<void>();
    releaseFirstWrite = Completer<void>();
    final storage = _Storage();
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((call) async => values[call.namedArguments[#key]]);
    when(() => storage.readAll()).thenAnswer((_) async => Map.of(values));
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((call) async {
      values.remove(call.namedArguments[#key]);
    });
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((call) async {
      if (!firstWriteStarted.isCompleted) {
        firstWriteStarted.complete();
        await releaseFirstWrite.future;
      }
      values[call.namedArguments[#key] as String] =
          call.namedArguments[#value] as String;
    });
    drafts = JournalDraftStore(storage: storage);
    repository = _Repository();
    when(() => repository.uid).thenReturn('a');
    when(() => repository.isCurrentSession).thenReturn(true);
    when(() => repository.saveEntry(any())).thenAnswer((_) async {});
  });
  tearDown(() {
    if (!releaseFirstWrite.isCompleted) releaseFirstWrite.complete();
    for (final current in editors) {
      current.dispose();
    }
  });

  test(
    'reopening during slow writes restores and saves the final snapshot',
    () async {
      final previous = editor();
      await pendingChanges(previous);
      previous.dispose();
      editors.remove(previous);
      final reopened = editor();
      final restoring = reopened.restore();
      releaseFirstWrite.complete();
      await restoring;
      expect(reopened.observation, 'last snapshot');
      expect(await reopened.save(), isTrue);
      final input =
          verify(() => repository.saveEntry(captureAny())).captured.single
              as JournalEntryInput;
      expect(input.entry.observation, 'last snapshot');
      expect(await drafts.read('a', 'pet', 'new'), isNull);
    },
  );

  test(
    'discard is ordered before a new editor restore and cannot resurrect',
    () async {
      final previous = editor();
      await pendingChanges(previous);
      final discarding = previous.discard();
      final reopened = editor();
      final restoring = reopened.restore();
      releaseFirstWrite.complete();
      await Future.wait([discarding, restoring]);
      expect(reopened.observation, isEmpty);
      expect(await drafts.read('a', 'pet', 'new'), isNull);
    },
  );

  test(
    'logout clears all pending old writes and preserves another account',
    () async {
      final previous = editor();
      await pendingChanges(previous);
      when(() => repository.isCurrentSession).thenReturn(false);
      final clearing = drafts.clearUser('a');
      final other = drafts.save('b', 'pet', 'new', {
        'observation': 'private B',
      });
      previous.changed(observation: 'late change', action: '', outcome: '');
      releaseFirstWrite.complete();
      await Future.wait([clearing, other]);
      expect(await drafts.read('a', 'pet', 'new'), isNull);
      expect(
        (await drafts.read('b', 'pet', 'new'))!['observation'],
        'private B',
      );
      expect(await previous.save(), isFalse);
      verifyNever(() => repository.saveEntry(any()));
    },
  );
}
