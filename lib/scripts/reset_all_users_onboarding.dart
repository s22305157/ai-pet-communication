import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;
  final usersRef = firestore.collection('Users');
  
  print('開始重置所有用戶的導引狀態...');
  
  final snapshots = await usersRef.get();
  int count = 0;
  
  for (var doc in snapshots.docs) {
    await doc.reference.update({
      'has_completed_onboarding': false,
      'onboarding_answers': FieldValue.delete(),
    });
    count++;
    print('已重置用戶: ${doc.id}');
  }
  
  print('完成！共重置 $count 名用戶。');
}
