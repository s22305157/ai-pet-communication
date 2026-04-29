import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'local_pet_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final LocalPetService _localPetService = LocalPetService();

  AuthService() {
    if (kIsWeb) {
      _auth.setPersistence(Persistence.LOCAL);
    }
  }

  // 獲取當前用戶數據流 (即時監聽 Firestore)
  Stream<UserModel?> getUserStream() {
    return _auth.authStateChanges().map((user) {
      if (user == null) return null;
      return user.uid;
    }).distinct().asyncExpand((uid) {
      if (uid == null) return Stream.value(null);
      return _db.collection('Users').doc(uid).snapshots().map((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          return UserModel.fromMap(snapshot.data() as Map<String, dynamic>);
        }
        return null;
      });
    });
  }

  // 獲取當前用戶數據 (單次)
  Future<UserModel?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    final doc = await _db.collection('Users').doc(user.uid).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  // 檢查是否為 Pro 以上用戶 (SSOT)
  Future<bool> isProUser() async {
    final user = await getUserData();
    if (user == null) return false;
    final type = user.membershipType.toLowerCase();
    return type == 'pro' || type == 'plus';
  }

  // 執行 Google 登入
  Future<UserModel?> signInWithGoogle() async {
    try {
      UserCredential userCredential;
      if (kIsWeb) {
        GoogleAuthProvider authProvider = GoogleAuthProvider();
        userCredential = await _auth.signInWithPopup(authProvider);
      } else {
        await GoogleSignIn.instance.initialize();
        final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate();
        if (googleUser == null) return null;
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
        userCredential = await _auth.signInWithCredential(credential);
      }

      User? user = userCredential.user;
      if (user != null) {
        return await _initializeUser(user);
      }
      return null;
    } catch (e) {
      debugPrint("Login Error: $e");
      rethrow;
    }
  }

  // 初始化用戶文檔
  Future<UserModel> _initializeUser(User user) async {
    DocumentReference userRef = _db.collection('Users').doc(user.uid);
    DocumentSnapshot doc = await userRef.get();

    if (!doc.exists) {
      final newUser = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? '毛小孩主人',
        photoURL: user.photoURL,
        points: 1,
        membershipType: 'free',
      );
      await userRef.set(newUser.toMap());
      return newUser;
    } else {
      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    }
  }

  // 登出並清理本地資料
  Future<void> signOut() async {
    await _localPetService.clearAll(); // 清理 Hive
    await _auth.signOut();
    if (!kIsWeb) {
      await GoogleSignIn.instance.signOut();
    }
  }

  // 刪除帳號
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _db.collection('Users').doc(user.uid).delete();
      await user.delete();
      await _localPetService.clearAll();
    }
  }

  // 更新會員等級 (測試/升級用)
  Future<void> updateMembership(String type) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _db.collection('Users').doc(user.uid).update({'membership_type': type});
    }
  }
}
