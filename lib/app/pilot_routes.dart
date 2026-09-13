import 'package:flutter/material.dart';
import 'package:ai_pet_communication/core/domain/request_repository.dart';
import '../features/journal/domain/journal_entry.dart';
import '../features/journal/domain/journal_repository.dart';

/// Application navigation contract; features do not import one another's screens.
abstract interface class PilotRoutes {
  Future<void> review(
    BuildContext context,
    RequestRepository repository,
    String petId, {
    String? week,
  });
  Future<void> community(BuildContext context, RequestRepository repository);
  Future<void> post(
    BuildContext context,
    RequestRepository repository,
    String postId,
  );
  Future<void> share(
    BuildContext context,
    RequestRepository repository,
    JournalRepository journal,
    String petId,
    JournalEntry entry,
  );
  Future<void> notifications(
    BuildContext context,
    RequestRepository repository,
  );
  Future<void> admin(BuildContext context, RequestRepository repository);
  Future<void> interest(BuildContext context, RequestRepository repository);
}
