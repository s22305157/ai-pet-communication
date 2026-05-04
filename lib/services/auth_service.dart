import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:rxdart/rxdart.dart';
import '../models/user_model.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final BehaviorSubject<UserModel?> _userSubject = BehaviorSubject<UserModel?>();

  Stream<UserModel?> getUserStream() {
    if (!_userSubject.hasListener) {
      _auth.authStateChanges().listen((User? user) async {
        if (user == null) {
          _userSubject.add(null);
        } else {
          try {
            final doc = await _db.collection('users').doc(user.uid).get();
            if (doc.exists) {
              _userSubject.add(UserModel.fromMap(doc.data()!, user.uid));
            } else {
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
              _userSubject.add(newUser);
            }
          } catch (e) {
            _userSubject.add(null);
          }
        }
      });
    }
    return _userSubject.stream;
  }

  Future<UserModel?> signInWithGoogle() async {
    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
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
    await _auth.signOut();
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

  // ---------------------------------------------------------
  // 補齊缺失的功能方法
  // ---------------------------------------------------------

  Future<void> addPoints(int points) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).update({
      'points': FieldValue.increment(points),
    });
  }

  Future<void> consumePoints(int points) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).update({
      'points': FieldValue.increment(-points),
    });
  }

  Future<void> updateOnboardingStatus(bool status, Map<String, dynamic> answers) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).update({
      'hasCompletedOnboarding': status,
      'onboardingAnswers': answers,
    });
  }

  Future<void> updateMembership(String tier) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).update({
      'membershipTier': tier,
    });
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    // 先刪除 Firestore 資料
    await _db.collection('users').doc(user.uid).delete();
    // 再刪除 Auth 帳號
    await user.delete();
  }

  UserModel? get currentUser => _userSubject.valueOrNull;
}
