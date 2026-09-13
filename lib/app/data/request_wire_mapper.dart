import 'package:ai_pet_communication/core/domain/app_request.dart';
import '../../features/pilot/domain/pilot_request.dart';
import '../../features/pilot/data/pilot_wire_mapper.dart';
import '../../features/community/domain/community_request.dart';
import '../../features/community/data/community_wire_mapper.dart';
import '../../features/weekly_review/domain/weekly_review_request.dart';
import '../../features/weekly_review/data/weekly_review_wire_mapper.dart';

(String, Map<String, dynamic>) encodeAppRequest(AppRequest request) =>
    switch (request) {
      PilotRequest r => encodePilotRequest(r),
      CommunityRequest r => encodeCommunityRequest(r),
      WeeklyReviewRequest r => encodeWeeklyReviewRequest(r),
      _ => throw UnsupportedError('Unregistered feature request'),
    };

T decodeAppResponse<T>(AppRequest<T> request, Map<String, dynamic> data) =>
    switch (request) {
      PilotRequest<T> r => decodePilotResponse(r, data),
      CommunityRequest<T> r => decodeCommunityResponse(r, data),
      WeeklyReviewRequest<T> r => decodeWeeklyReviewResponse(r, data),
      _ => throw UnsupportedError('Unregistered feature request'),
    };
