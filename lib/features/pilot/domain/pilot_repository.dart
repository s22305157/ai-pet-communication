import 'pilot_request.dart';

abstract interface class PilotRepository {
  Future<T> execute<T>(PilotRequest<T> request, {String? operationId});
  String requestKey(PilotRequest<void> request);
  String get uid;
  bool get isCurrentSession;
  Stream<bool> get sessionChanges;
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]);
}
