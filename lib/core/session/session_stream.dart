import 'dart:async';
import 'current_session.dart';

/// Starts listening for sign-out before creating the protected data source.
Stream<T> watchSession<T>(
  CurrentSession session,
  String uid,
  Future<Stream<T>> Function() source,
  T cleared,
) {
  late final StreamController<T> controller;
  StreamSubscription<String?>? auth;
  StreamSubscription<T>? data;
  var stopped = false;
  Future<void> stop() async {
    if (stopped) return;
    stopped = true;
    controller.add(cleared);
    unawaited(controller.close());
    await data?.cancel();
    await auth?.cancel();
  }

  controller = StreamController<T>(
    onListen: () {
      auth = session.userIdChanges.listen(
        (active) {
          if (active != uid) unawaited(stop());
        },
        onError: (Object error, StackTrace stack) {
          if (!stopped) controller.addError(error, stack);
          unawaited(stop());
        },
      );
      unawaited(() async {
        try {
          final stream = await source();
          if (stopped) return;
          if ((await session.getUserData())?.uid != uid) {
            await stop();
            return;
          }
          if (stopped) return;
          data = stream.listen(
            (event) {
              if (!stopped) controller.add(event);
            },
            onError: (Object error, StackTrace stack) {
              if (!stopped) controller.addError(error, stack);
            },
            onDone: () {
              unawaited(stop());
            },
          );
        } catch (error, stack) {
          if (!stopped) controller.addError(error, stack);
          await stop();
        }
      }());
    },
    onCancel: () async {
      stopped = true;
      await auth?.cancel();
      await data?.cancel();
    },
  );
  return controller.stream;
}
