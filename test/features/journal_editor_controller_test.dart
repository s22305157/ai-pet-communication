import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ai_pet_communication/core/errors/service_failure.dart';
import 'package:ai_pet_communication/features/journal/application/journal_editor_controller.dart';
import 'package:ai_pet_communication/features/journal/domain/journal_repository.dart';
import 'package:ai_pet_communication/features/journal/domain/journal_drafts.dart';
import 'package:ai_pet_communication/features/journal/domain/journal_entry.dart';

class Repository extends Mock implements JournalRepository {}

class Drafts extends Mock implements JournalDrafts {}

void main() {
  late Repository repository;
  late Drafts drafts;
  late JournalEditorController editor;
  setUp(() {
    repository = Repository();
    drafts = Drafts();
    when(() => repository.uid).thenReturn('a');
    when(() => repository.isCurrentSession).thenReturn(true);
    when(() => drafts.read('a', 'pet', 'new')).thenAnswer((_) async => null);
    when(() => drafts.save('a', 'pet', 'new', any())).thenAnswer((_) async {});
    when(() => drafts.remove('a', 'pet', 'new')).thenAnswer((_) async {});
    editor = JournalEditorController(
      repository: repository,
      drafts: drafts,
      petId: 'pet',
    );
  });
  tearDown(() => editor.dispose());

  test(
    'closing the editor preserves an already queued draft for the same account',
    () async {
      final detached = JournalEditorController(
        repository: repository,
        drafts: drafts,
        petId: 'pet',
      );
      await detached.restore();
      detached.changed(observation: '最後輸入', action: '', outcome: '');
      detached.dispose();
      await Future<void>.delayed(Duration.zero);
      verify(
        () => drafts.save(
          'a',
          'pet',
          'new',
          any(that: containsPair('observation', '最後輸入')),
        ),
      ).called(1);
    },
  );

  test(
    'conflict retains the draft and prevents another save with a stale revision',
    () async {
      await editor.restore();
      editor.changed(observation: '今天的小事', action: '', outcome: '');
      registerFallbackValue(
        JournalEntryInput(
          petId: 'pet',
          operationId: 'id',
          entry: JournalEntry(
            id: 'entry',
            occurredAt: DateTime(2026),
            context: '休息',
            observation: '',
            action: '',
            outcome: '',
            mediaIds: [],
            revision: 0,
          ),
        ),
      );
      when(
        () => repository.saveEntry(any()),
      ).thenThrow(const ServiceFailure(FailureKind.conflict));
      expect(await editor.save(), isFalse);
      expect(editor.conflict, isTrue);
      expect(await editor.save(), isFalse);
      verify(() => repository.saveEntry(any())).called(1);
      verifyNever(() => drafts.remove(any(), any(), any()));
    },
  );

  test(
    'discard waits for queued draft writes so a late write cannot resurrect it',
    () async {
      final pending = Completer<void>();
      when(
        () => drafts.save('a', 'pet', 'new', any()),
      ).thenAnswer((_) => pending.future);
      await editor.restore();
      editor.changed(observation: '保留草稿', action: '', outcome: '');
      final discard = editor.discard();
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => drafts.remove(any(), any(), any()));
      pending.complete();
      await discard;
      verify(() => drafts.remove('a', 'pet', 'new')).called(1);
    },
  );
}
