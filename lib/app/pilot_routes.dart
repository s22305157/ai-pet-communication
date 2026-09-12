import 'package:flutter/material.dart';
import '../features/pilot/domain/pilot_repository.dart';
import '../features/journal/domain/journal_entry.dart';
import '../features/journal/domain/journal_repository.dart';

/// Application navigation contract; features do not import one another's screens.
abstract interface class PilotRoutes {
  Future<void> review(
    BuildContext context,
    PilotRepository repository,
    String petId, {
    String? week,
  });
  Future<void> community(BuildContext context, PilotRepository repository);
  Future<void> post(
    BuildContext context,
    PilotRepository repository,
    String postId,
  );
  Future<void> share(
    BuildContext context,
    PilotRepository repository,
    JournalRepository journal,
    String petId,
    JournalEntry entry,
  );
  Future<void> notifications(BuildContext context, PilotRepository repository);
  Future<void> admin(BuildContext context, PilotRepository repository);
  Future<void> interest(BuildContext context, PilotRepository repository);
}
