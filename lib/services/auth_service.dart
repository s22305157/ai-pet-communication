import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AuthService() {
    // 明確設定持久化 (Web 端預設即為 local，但明確設定更保險)
    if (kIsWeb) {
      _auth.setPersistence(Persistence.LOCAL);
    }
  }

  // 執行登入並初始化用戶
  Future<UserModel?> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // Web 平台：直接使用 Firebase Auth Popup
        // 這是網頁端最推薦的方式，可以避開跨域與套件版本問題
        GoogleAuthProvider authProvider = GoogleAuthProvider();
        userCredential = await _auth.signInWithPopup(authProvider);
      } else {
        // Android / iOS 平台：使用 google_sign_in 7.x 新 API
        await GoogleSignIn.instance.initialize(); // 7.x 必須先初始化
        final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate();
        
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth = googleUser.authentication;
        
        // 取得 Credential (7.x 的 Token 取得方式有所調整)
        final AuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }

      User? user = userCredential.user;
      if (user != null) {
        return await _initializeUser(user);
      }
      return null;
    } catch (e) {
      print("Login Error: $e");
      rethrow;
    }
  }

  // 初始化用戶文檔並返回 UserModel
  Future<UserModel> _initializeUser(User user) async {
    DocumentReference userRef = _db.collection('Users').doc(user.uid);
    DocumentSnapshot doc = await userRef.get();

    if (!doc.exists) {
      final newUser = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? '毛小孩主人',
        photoURL: user.photoURL,
        points: 1, // 初始點數
      );
      await userRef.set(newUser.toFirestore());
      return newUser;
    } else {
      return UserModel.fromFirestore(doc);
    }
  }

  // 檢查使用者是否還有點數
  Future<bool> hasEnoughPoints() async {
    User? user = _auth.currentUser;
    if (user == null) return false;

    DocumentSnapshot doc = await _db.collection('Users').doc(user.uid).get();
    if (!doc.exists) return false;

    int points = (doc.data() as Map<String, dynamic>)['points'] ?? 0;
    return points > 0;
  }

  // 扣除點數 (執行 AI 溝通時呼叫)
  Future<void> consumePoint() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    DocumentReference userRef = _db.collection('Users').doc(user.uid);
    
    // 使用原子操作 (increment -1) 確保併發安全
    await userRef.update({
      'points': FieldValue.increment(-1),
      'total_readings': FieldValue.increment(1),
    });
  }

  // 取得當前用戶的即時資料流 (回傳 UserModel)
  Stream<UserModel?> getUserStream() {
    User? user = _auth.currentUser;
    if (user != null) {
      return _db.collection('Users').doc(user.uid).snapshots().map((doc) {
        if (doc.exists) {
          return UserModel.fromFirestore(doc);
        }
        return null;
      });
    }
    return Stream.value(null);
  }

  // 取得當前用戶的單次資料快照 (用於關鍵動作判定)
  Future<UserModel?> getUserData() async {
    User? user = _auth.currentUser;
    if (user == null) return null;

    DocumentSnapshot doc = await _db.collection('Users').doc(user.uid).get();
    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    }
    return null;
  }

  // 登出
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await GoogleSignIn.instance.signOut();
      }
      await _auth.signOut();
    } catch (e) {
      print("Logout Error: $e");
      rethrow;
    }
  }

  // 刪除帳號
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // 1. 刪除 Firestore 中的用戶資料
      await _db.collection('Users').doc(user.uid).delete();

      // 2. 刪除 Firebase Auth 帳號
      await user.delete();
    } catch (e) {
      print("Delete Account Error: $e");
      rethrow;
    }
  }
}
