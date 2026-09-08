# 維運腳本

此目錄保留原 `lib/scripts` 的一次性帳號維運程式，不是 Flutter app 的入口。
正式 analyze 排除此目錄；需要執行時應另行檢查腳本所指向的 Firebase 專案及資料範圍。

產品品質關卡：`flutter analyze --no-pub`、`flutter test --no-pub`、`flutter build web --release --no-pub`。
