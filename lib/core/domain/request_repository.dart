import 'app_request.dart';

abstract interface class RequestRepository {
  Future<T> execute<T>(AppRequest<T> request, {String? operationId});
  String requestKey(AppRequest<void> request);
  String get uid;
  bool get isCurrentSession;
  Stream<bool> get sessionChanges;
}
