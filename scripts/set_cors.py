"""
使用 Firebase CLI 的認證 token 透過 GCS REST API 設定 Firebase Storage 的 CORS 規則
"""
import subprocess
import json
import urllib.request
import urllib.error

BUCKET = "fir-project-tw.firebasestorage.app"

CORS = [
    {
        "origin": [
            "http://localhost:8080",
            "http://localhost",
            "https://fir-project-tw.web.app",
            "https://fir-project-tw.firebaseapp.com",
            "*"
        ],
        "method": ["GET", "HEAD", "OPTIONS"],
        "responseHeader": ["Content-Type", "Authorization", "x-goog-meta-*"],
        "maxAgeSeconds": 3600
    }
]

def get_firebase_token():
    """從 Firebase CLI config 讀取 access token"""
    import os
    import glob

    # Windows: Firebase CLI 把 token 存在 AppData
    appdata = os.environ.get("APPDATA", "")
    config_paths = glob.glob(os.path.join(appdata, "npm", "node_modules", "firebase-tools", "**"), recursive=True)
    
    # 嘗試用 firebase token 指令
    try:
        result = subprocess.run(
            ["firebase", "login:export", "--no-interactive"],
            capture_output=True, text=True, timeout=10
        )
        print("firebase login:export:", result.stdout[:200], result.stderr[:200])
    except Exception as e:
        print(f"firebase login:export failed: {e}")

    # 讀取 Firebase CLI 的 config file
    config_file = os.path.join(os.environ.get("APPDATA", ""), "firebase", "config")
    print(f"Checking config at: {config_file}")
    
    # 嘗試讀取 credentials
    credentials_file = os.path.join(os.environ.get("APPDATA", ""), "gcloud", "application_default_credentials.json")
    print(f"Checking gcloud credentials at: {credentials_file}")
    if os.path.exists(credentials_file):
        with open(credentials_file) as f:
            creds = json.load(f)
            print(f"Found gcloud credentials: type={creds.get('type')}")
            return creds
    
    return None

def use_python_google_auth():
    """嘗試用 google-auth 套件取得 token"""
    try:
        import google.auth
        import google.auth.transport.requests
        
        credentials, project = google.auth.default(
            scopes=["https://www.googleapis.com/auth/devstorage.full_control"]
        )
        request = google.auth.transport.requests.Request()
        credentials.refresh(request)
        return credentials.token
    except ImportError:
        print("google-auth not installed, installing...")
        subprocess.run(["pip", "install", "google-auth", "-q"], check=True)
        return use_python_google_auth()
    except Exception as e:
        print(f"google-auth failed: {e}")
        return None

def set_cors_with_token(token):
    url = f"https://storage.googleapis.com/storage/v1/b/{BUCKET}?fields=cors"
    data = json.dumps({"cors": CORS}).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        method="PATCH",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }
    )
    try:
        with urllib.request.urlopen(req) as resp:
            result = json.loads(resp.read())
            print(f"✅ CORS 設定成功！")
            print(json.dumps(result, indent=2))
            return True
    except urllib.error.HTTPError as e:
        print(f"❌ HTTP Error: {e.code} {e.reason}")
        print(e.read().decode())
        return False

if __name__ == "__main__":
    print("嘗試取得 Google Cloud 認證...")
    token = use_python_google_auth()
    if token:
        print(f"✅ 取得 token (前20字): {token[:20]}...")
        set_cors_with_token(token)
    else:
        print("❌ 無法取得 token，請確保已登入 gcloud 或設定 ADC 憑證")
        get_firebase_token()
