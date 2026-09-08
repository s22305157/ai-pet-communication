/// Shared by online writes and reconciliation, keyed by account.
class MutationQueue {
  final Map<String, Future<void>> _tails = {};
  Future<T> run<T>(String uid, Future<T> Function() work) {
    final result = (_tails[uid] ?? Future<void>.value()).then((_) => work());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tails[uid] = tail;
    tail.then((_) {
      if (identical(_tails[uid], tail)) _tails.remove(uid);
    });
    return result;
  }
}
