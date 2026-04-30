import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'local_pet_service.dart';
import 'subscription_service.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final LocalPetService _localPetService;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    LocalPetService? localService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance,
        _localPetService = localService ?? LocalPetService() {
    if (kIsWeb) {
      _auth.setPersistence(Persistence.LOCAL);
    }
  }

  // 獲取當前用戶數據流 (即時監聽 Firestore)
  Stream<UserModel?> getUserStream() {
    late StreamController<UserModel?> controller;
    StreamSubscription<User?>? authSub;
    StreamSubscription<DocumentSnapshot>? docSub;

    controller = StreamController<UserModel?>.broadcast(
      onListen: () {
        authSub = _auth.authStateChanges().listen((user) {
          docSub?.cancel();
          if (user == null) {
            controller.add(null);
          } else {
            docSub = _db.collection('Users').doc(user.uid).snapshots().listen((snapshot) {
              if (snapshot.exists && snapshot.data() != null) {
                controller.add(UserModel.fromMap(snapshot.data() as Map<String, dynamic>));
              } else {
                controller.add(null);
              }
            });
          }
        });
      },
      onCancel: () {
        authSub?.cancel();
        docSub?.cancel();
      },
    );

    return controller.stream;
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
        final userModel = await _initializeUser(user);
        await syncSubscriptionStatus(); // 同步訂閱狀態
        return userModel;
      }
      return null;
    } catch (e) {
      debugPrint("登入錯誤: $e");
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
    await SubscriptionService().logOut(); // 登出 RevenueCat
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

  // 同步訂閱狀態至 Firestore (整合 RevenueCat)
  Future<void> syncSubscriptionStatus() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final subscriptionService = SubscriptionService();
    // 登入 RevenueCat 以確保關聯正確
    await subscriptionService.logIn(user.uid);
    
    final realStatus = await subscriptionService.checkEntitlementStatus();
    
    final doc = await _db.collection('Users').doc(user.uid).get();
    if (doc.exists) {
      final currentType = doc.data()?['membership_type'] ?? 'free';
      if (currentType != realStatus) {
        await updateMembership(realStatus);
        debugPrint('AuthService: 訂閱狀態已從 $currentType 同步為 $realStatus');
      }
    }
  }

  // 消耗點數
  Future<void> consumePoints(int amount) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    await _db.collection('Users').doc(user.uid).update({
      'points': FieldValue.increment(-amount),
    });
  }

  // 增加點數
  Future<void> addPoints(int amount) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    await _db.collection('Users').doc(user.uid).update({
      'points': FieldValue.increment(amount),
    });
  }
}
