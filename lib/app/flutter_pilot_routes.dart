import 'package:flutter/material.dart';
import 'pilot_routes.dart';
import '../features/pilot/domain/pilot_repository.dart';
import '../features/journal/domain/journal_entry.dart';
import '../features/journal/domain/journal_repository.dart';
import '../features/journal/presentation/journal_image.dart';
import '../features/weekly_review/presentation/weekly_review_screen.dart';
import '../features/community/presentation/community_screen.dart';
import '../features/community/presentation/community_post_screen.dart';
import '../features/community/presentation/community_share_screen.dart';
import '../features/pilot/presentation/pilot_notifications_screen.dart';
import '../features/pilot/presentation/pilot_admin_screen.dart';

class FlutterPilotRoutes implements PilotRoutes {
  Future<void> _open(BuildContext context, Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Future<void> review(
    BuildContext context,
    PilotRepository repository,
    String petId, {
    String? week,
  }) => _open(
    context,
    WeeklyReviewScreen(repository: repository, petId: petId, initialWeek: week),
  );
  @override
  Future<void> community(BuildContext context, PilotRepository repository) =>
      _open(context, CommunityScreen(repository: repository));
  @override
  Future<void> post(
    BuildContext context,
    PilotRepository repository,
    String postId,
  ) => _open(
    context,
    CommunityPostScreen(repository: repository, postId: postId),
  );
  @override
  Future<void> share(
    BuildContext context,
    PilotRepository repository,
    JournalRepository journal,
    String petId,
    JournalEntry entry,
  ) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityShareScreen(
          repository: repository,
          petId: petId,
          entry: entry,
          sourceImageBuilder: (id) =>
              JournalImage(repository: journal, mediaId: id),
        ),
      ),
    );
  }

  @override
  Future<void> notifications(
    BuildContext context,
    PilotRepository repository,
  ) => _open(
    context,
    PilotNotificationsScreen(repository: repository, routes: this),
  );
  @override
  Future<void> admin(BuildContext context, PilotRepository repository) =>
      _open(context, PilotAdminScreen(repository: repository));
}
