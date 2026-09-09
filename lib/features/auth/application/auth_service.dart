import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';
import '../data/user_mapper.dart';
import 'package:rxdart/rxdart.dart';
import 'package:ai_pet_communication/core/session/current_session.dart';
import 'package:ai_pet_communication/core/storage/account_cleanup.dart';
import 'package:ai_pet_communication/models/user_model.dart';

class AuthService implements CurrentSession {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    AccountCleanup? cleanup,
    AccountCleanup? sessionCleanup,
    FirebaseFunctions? functions,
  }) : _customAuth = auth,
       _customDb = firestore,
       _cleanup = cleanup,
       _sessionCleanup = sessionCleanup,
       _functions = functions;
  final FirebaseFunctions? _functions;
  final AccountCleanup? _cleanup;
  final AccountCleanup? _sessionCleanup;

  final FirebaseAuth? _customAuth;
  final FirebaseFirestore? _customDb;

  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _db => _customDb ?? FirebaseFirestore.instance;

  final BehaviorSubject<UserModel?> _userSubject =
      BehaviorSubject<UserModel?>();
  StreamSubscription<User?>? _authStateSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _userDocumentSubscription;
  int _authGeneration = 0;
  Timer? _membershipExpiryTimer;

  void _publishUser(UserModel user, int generation) {
    _membershipExpiryTimer?.cancel();
    _userSubject.add(user);
    final expiry = user.membershipExpiresAt;
    if (expiry == null) return;
    final delay = expiry.difference(DateTime.now());
    // Cap long timers for Web, and recalculate when the timer fires.
    _membershipExpiryTimer = Timer(
      delay > const Duration(days: 1)
          ? const Duration(days: 1)
          : (delay.isNegative
                ? Duration.zero
                : delay + const Duration(milliseconds: 1)),
      () {
        if (generation == _authGeneration) _publishUser(user, generation);
      },
    );
  }

  @override
  Stream<String?> get userIdChanges =>
      _auth.authStateChanges().map((user) => user?.uid).distinct();

  Stream<UserModel?> getUserStream() {
    _ensureUserStreamStarted();
    return _userSubject.stream;
  }

  void _ensureUserStreamStarted() {
    _authStateSubscription ??= _auth.authStateChanges().listen(
      (user) => unawaited(_switchUserDocument(user)),
      onError: (Object error, StackTrace stackTrace) {
        _userSubject.addError(error, stackTrace);
      },
    );
  }

  Future<void> _switchUserDocument(User? user) async {
    final generation = ++_authGeneration;
    _membershipExpiryTimer?.cancel();
    final previousSubscription = _userDocumentSubscription;
    _userDocumentSubscription = null;
    await previousSubscription?.cancel();

    if (generation != _authGeneration) return;
    // Never retain the previous account while the next document is loading.
    if (_userSubject.valueOrNull?.uid != user?.uid) _userSubject.add(null);
    if (user == null) {
      _userSubject.add(null);
      return;
    }

    final userRef = _db.collection('users').doc(user.uid);
    var isCreatingUser = false;
    _userDocumentSubscription = userRef.snapshots().listen(
      (snapshot) {
        if (generation != _authGeneration) return;
        if (snapshot.exists) {
          try {
            _publishUser(
              UserMapper.fromMap(snapshot.data()!, user.uid),
              generation,
            );
          } catch (error, stack) {
            _userSubject.addError(error, stack);
          }
          return;
        }
        if (isCreatingUser) return;
        isCreatingUser = true;
        unawaited(_createMissingUser(userRef, user, generation));
      },
      onError: (Object error, StackTrace stackTrace) {
        unawaited(
          _handleDocumentError(user.uid, generation, error, stackTrace),
        );
      },
    );
  }

  Future<void> _handleDocumentError(
    String uid,
    int generation,
    Object error,
    StackTrace stack,
  ) async {
    if (generation != _authGeneration) return;
    if (error is FirebaseException &&
        error.code == 'permission-denied' &&
        _functions != null) {
      try {
        final result = await _functions
            .httpsCallable('getAccountDeletionStatus')
            .call<Map<String, dynamic>>();
        if (generation != _authGeneration) return;
        if (result.data['accepted'] == true) {
          await _finishAccountDeletion(uid);
          return;
        }
      } catch (_) {}
    }
    if (generation == _authGeneration) _userSubject.addError(error, stack);
  }

  Future<void> _finishAccountDeletion(String uid) async {
    try {
      await _cleanup?.clearUser(uid);
    } finally {
      if (_auth.currentUser?.uid == uid) await signOut();
    }
  }

  Future<void> _createMissingUser(
    DocumentReference<Map<String, dynamic>> userRef,
    User user,
    int generation,
  ) async {
    try {
      await _ensureUser(user);
    } catch (error, stackTrace) {
      if (generation == _authGeneration) {
        _userSubject.addError(error, stackTrace);
      }
    }
  }

  Future<UserModel> _ensureUser(User user) => _db.runTransaction((
    transaction,
  ) async {
    final reference = _db.collection('users').doc(user.uid);
    final snapshot = await transaction.get(reference);
    if (snapshot.exists) return UserMapper.fromMap(snapshot.data()!, user.uid);
    final created = _newUser(user);
    transaction.set(reference, UserMapper.toMap(created));
    return created;
  });

  UserModel _newUser(User user) {
    return UserModel(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? '新朋友',
      photoUrl: user.photoURL,
      points: 1,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
  }

  Future<UserModel?> signInWithGoogle() async {
    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      UserCredential userCredential = await _auth.signInWithPopup(
        googleProvider,
      );
      User? user = userCredential.user;

      if (user != null) {
        final doc = await _db.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          return _ensureUser(user);
        } else {
          await _db.collection('users').doc(user.uid).update({
            'lastLoginAt': FieldValue.serverTimestamp(),
          });
          return UserMapper.fromMap(doc.data()!, user.uid);
        }
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }

  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    _membershipExpiryTimer?.cancel();
    final generation = ++_authGeneration;
    final previousSubscription = _userDocumentSubscription;
    _userDocumentSubscription = null;
    await previousSubscription?.cancel();
    if (generation == _authGeneration) _userSubject.add(null);

    try {
      await _auth.signOut();
      if (uid != null) await _sessionCleanup?.clearUser(uid);
    } catch (_) {
      await _switchUserDocument(_auth.currentUser);
      rethrow;
    }
  }

  @override
  Future<UserModel?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _db.collection('users').doc(user.uid).get();
    if (_auth.currentUser?.uid != user.uid) return null;
    if (doc.exists) {
      return UserMapper.fromMap(doc.data()!, user.uid);
    }
    return null;
  }

  Future<void> updateOnboardingStatus(
    bool status,
    Map<String, dynamic> answers,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Authentication required.');
    await _db.collection('users').doc(user.uid).update({
      'hasCompletedOnboarding': status,
      'onboardingAnswers': answers,
    });
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.reauthenticateWithProvider(GoogleAuthProvider());
    final generation = ++_authGeneration;
    final previousSubscription = _userDocumentSubscription;
    _userDocumentSubscription = null;
    await previousSubscription?.cancel();
    try {
      await (_functions ?? FirebaseFunctions.instance)
          .httpsCallable('deleteOwnAccount')
          .call();
    } catch (error) {
      var accepted = false;
      try {
        final status = await (_functions ?? FirebaseFunctions.instance)
            .httpsCallable('getAccountDeletionStatus')
            .call<Map<String, dynamic>>();
        accepted = status.data['accepted'] == true;
      } catch (_) {}
      if (!accepted) {
        if (generation == _authGeneration) {
          await _switchUserDocument(_auth.currentUser);
        }
        rethrow;
      }
    }
    await _finishAccountDeletion(user.uid);
  }

  Future<void> dispose() async {
    _membershipExpiryTimer?.cancel();
    ++_authGeneration;
    await _authStateSubscription?.cancel();
    await _userDocumentSubscription?.cancel();
    await _userSubject.close();
  }

  UserModel? get currentUser => _userSubject.valueOrNull;
}
