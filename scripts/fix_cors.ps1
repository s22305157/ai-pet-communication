$env:Path += ";$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk\bin"
Write-Host "即將開啟瀏覽器讓您登入 Google 帳號授權..." -ForegroundColor Cyan
Write-Host "請登入您建立此 Firebase 專案的 Google 帳號。" -ForegroundColor Yellow

gcloud auth login

Write-Host "登入成功！正在為您的 Firebase Storage 儲存桶設定 CORS 權限..." -ForegroundColor Cyan
gsutil cors set cors.json gs://fir-project-tw.firebasestorage.app

Write-Host "設定完成！請回到網頁重新整理，頭像應該就能正常顯示了。" -ForegroundColor Green
Pause
