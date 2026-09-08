import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:hive/hive.dart';
import '../models/user_model.dart';
import '../features/pet/data/local_pet_service.dart';
import '../features/readings/data/local_readings_repository.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    dynamic localService,
  }) {
    if (auth != null || firestore != null) {
      return AuthService._test(auth, firestore);
    }
    return _instance;
  }

  AuthService._internal() : _customAuth = null, _customDb = null;

  AuthService._test(this._customAuth, this._customDb);

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
    final previousSubscription = _userDocumentSubscription;
    _userDocumentSubscription = null;
    await previousSubscription?.cancel();

    if (generation != _authGeneration) return;
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
          _userSubject.add(UserModel.fromMap(snapshot.data()!, user.uid));
          return;
        }
        if (isCreatingUser) return;
        isCreatingUser = true;
        unawaited(_createMissingUser(userRef, user, generation));
      },
      onError: (Object error, StackTrace stackTrace) {
        if (generation == _authGeneration) {
          _userSubject.addError(error, stackTrace);
        }
      },
    );
  }

  Future<void> _createMissingUser(
    DocumentReference<Map<String, dynamic>> userRef,
    User user,
    int generation,
  ) async {
    final newUser = UserModel(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? '新朋友',
      photoUrl: user.photoURL,
      points: 1,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
    try {
      await userRef.set(newUser.toMap());
    } catch (error, stackTrace) {
      if (generation == _authGeneration) {
        _userSubject.addError(error, stackTrace);
      }
    }
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
          final newUser = UserModel(
            uid: user.uid,
            email: user.email ?? '',
            displayName: user.displayName ?? '新朋友',
            photoUrl: user.photoURL,
            points: 1, // 符合安全規則：初始點數為 1
            createdAt: DateTime.now(),
            lastLoginAt: DateTime.now(),
          );
          await _db.collection('users').doc(user.uid).set(newUser.toMap());
          return newUser;
        } else {
          await _db.collection('users').doc(user.uid).update({
            'lastLoginAt': FieldValue.serverTimestamp(),
          });
          return UserModel.fromMap(doc.data()!, user.uid);
        }
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }

  Future<void> signOut() async {
    final generation = ++_authGeneration;
    final previousSubscription = _userDocumentSubscription;
    _userDocumentSubscription = null;
    await previousSubscription?.cancel();
    if (generation == _authGeneration) _userSubject.add(null);

    try {
      await _auth.signOut();
    } catch (_) {
      await _switchUserDocument(_auth.currentUser);
      rethrow;
    }
  }

  Future<UserModel?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _db.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data()!, user.uid);
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
      await FirebaseFunctions.instance.httpsCallable('deleteOwnAccount').call();
    } catch (_) {
      if (generation == _authGeneration) {
        await _switchUserDocument(_auth.currentUser);
      }
      rethrow;
    }
    try {
      if (Hive.isBoxOpen('local_pets')) {
        await LocalPetService(
          box: Hive.box<dynamic>('local_pets'),
        ).clearUser(user.uid);
      }
      if (Hive.isBoxOpen('local_readings')) {
        await LocalReadingsRepository(
          box: Hive.box<dynamic>('local_readings'),
        ).clearUser(user.uid);
      }
    } finally {
      await signOut();
    }
  }

  UserModel? get currentUser => _userSubject.valueOrNull;
}
