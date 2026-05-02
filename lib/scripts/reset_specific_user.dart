import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';
import '../models/user_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('正在初始化 Firebase...');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;
  final usersRef = firestore.collection('Users');
  
  const targetId = '4076853474';
  print('正在資料庫中尋找數字 ID 為 $targetId 的用戶...');
  
  final snapshots = await usersRef.get();
  bool found = false;
  
  for (var doc in snapshots.docs) {
    String numericId = UserModel.getNumericId(doc.id);
    if (numericId == targetId) {
      print('找到用戶！Firebase UID: ${doc.id}');
      print('正在標示為新用戶 (重置導引狀態)...');
      
      await doc.reference.update({
        'has_completed_onboarding': false,
        'onboarding_answers': FieldValue.delete(),
      });
      
      print('✅ 成功將用戶標示為新用戶。');
      found = true;
      break;
    }
  }
  
  if (!found) {
    print('❌ 找不到 ID 為 $targetId 的用戶。請確認您的 ID 是否正確。');
  }
  
  print('程序完成。');
}
