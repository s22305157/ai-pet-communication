import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 執行登入並初始化用戶
  Future<User?> signInWithGoogle() async {
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
        await _initializeUser(user);
      }
      return user;
    } catch (e) {
      print("Login Error: $e");
      rethrow;
    }
  }

  // 初始化用戶文檔 (維持您的原始設計)
  Future<void> _initializeUser(User user) async {
    DocumentReference userRef = _db.collection('Users').doc(user.uid);
    DocumentSnapshot doc = await userRef.get();

    if (!doc.exists) {
      await userRef.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'membership_type': 'free',
        'points': 1,
        'last_reset_date': FieldValue.serverTimestamp(),
        'client_version': '1.0.0',
        'total_readings': 0,
      });
      print("New user initialized with free points.");
    }
  }

  // 取得當前用戶的 Firestore 資料流 (用於即時更新點數)
  Stream<DocumentSnapshot>? getUserStream() {
    User? user = _auth.currentUser;
    if (user != null) {
      return _db.collection('Users').doc(user.uid).snapshots();
    }
    return null;
  }
}
