import 'package:flutter_test/flutter_test.dart';
import 'package:ai_pet_communication/features/pilot/data/pilot_wire_mapper.dart';
import 'package:ai_pet_communication/features/pilot/domain/pilot_request.dart';
import 'package:ai_pet_communication/features/community/domain/community_post.dart';

void main() {
  test('invalidated reviews discard stale or malformed AI payloads', () {
    final review = decodePilotResponse(
      const GetWeeklyReview(petId: 'pet', week: '2026-09-07'),
      {'status': 'invalidated', 'result': 'stale private content'},
    );
    expect(review.result, isNull);
    expect(review.canGenerate, isFalse);
    expect(review.analysisEnabled, isFalse);
  });

  test('malformed ready reviews fail in the data layer before rendering', () {
    expect(
      () => decodePilotResponse(
        const GetWeeklyReview(petId: 'pet', week: '2026-09-07'),
        {
          'status': 'ready',
          'result': {'happenings': 'wrong type'},
        },
      ),
      throwsA(isA<TypeError>()),
    );
  });

  test(
    'community pages parse cursor, permissions, counters and immutable media',
    () {
      final page = decodePilotResponse(
        const ListCommunityPosts(topic: '', mine: false),
        {
          'items': [
            {
              'id': 'p',
              'text': '分享',
              'alias': '同伴',
              'revision': 2,
              'createdAtMs': 1234,
              'own': true,
              'commentCount': 3,
              'encouragementCount': 4,
              'mediaIds': ['image'],
            },
          ],
          'cursor': {'id': 'p', 'time': 1234},
        },
      );
      expect(page.items.single.own, isTrue);
      expect(page.items.single.commentCount, 3);
      expect(page.items.single.encouragementCount, 4);
      expect(page.cursor!.time, 1234);
      expect(
        () => page.items.single.mediaIds.add('other'),
        throwsUnsupportedError,
      );
      expect(() => page.items.clear(), throwsUnsupportedError);
      expect(
        () => decodePilotResponse(const GetCommunityPost(postId: 'p'), {
          'text': 'missing identity',
        }),
        throwsFormatException,
      );
    },
  );

  test('typed request keeps paging and revision contracts outside the UI', () {
    final (name, values) = encodePilotRequest(
      const ListCommunityPosts(
        topic: '熟悉彼此',
        mine: false,
        cursor: PageCursor(id: 'p', time: 42),
      ),
    );
    expect(name, 'listCommunityPosts');
    expect(values['cursor'], {'id': 'p', 'time': 42});
    final (_, update) = encodePilotRequest(
      const EditCommunityPost(
        postId: 'p',
        text: '新版',
        topic: '熟悉彼此',
        expectedRevision: 3,
      ),
    );
    expect(update['expectedRevision'], 3);
    final (adminName, image) = encodePilotRequest(
      const GetCommunityImage(postId: 'unused', mediaId: 'm', reportId: 'r'),
    );
    expect(adminName, 'adminGetReportedImage');
    expect(image.containsKey('postId'), isFalse);
    expect(image['reportId'], 'r');
  });
}
