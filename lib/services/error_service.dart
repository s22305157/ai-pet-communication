import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ErrorService {
  static String getHumanReadableError(dynamic error) {
    // Firebase Auth 錯誤
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return '找不到此帳號，請確認 Email 是否正確。';
        case 'wrong-password':
          return '密碼錯誤，請再試一次。';
        case 'email-already-in-use':
          return '此 Email 已被註冊使用。';
        case 'network-request-failed':
          return '網路連線失敗，請檢查您的網路設定。';
        case 'too-many-requests':
          return '嘗試次數過多，帳號已被暫時鎖定，請稍後再試。';
        case 'operation-not-allowed':
          return '目前暫時無法使用此登入方式。';
        case 'invalid-email':
          return 'Email 格式不正確。';
        case 'requires-recent-login':
          return '為了安全起見，此操作需要您近期重新登入。';
        default:
          return '認證發生錯誤 (${error.code})，請聯繫支援。';
      }
    }

    // Firestore 錯誤
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return '權限不足，您可能沒有存取此資料的權限。';
        case 'unavailable':
          return '伺服器暫時無法連線，請檢查網路。';
        case 'not-found':
          return '找不到請求的資料。';
        case 'already-exists':
          return '資料已存在，請勿重複操作。';
        default:
          return '資料庫操作錯誤 (${error.code})，請稍後再試。';
      }
    }

    // 一般錯誤
    return error.toString().contains('SocketException') 
        ? '網路連線異常，請確認您的網路環境。' 
        : '發生意外錯誤，請稍後再試。';
  }
}
