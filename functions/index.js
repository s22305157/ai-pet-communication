const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

exports.corsProxy = onRequest({
  cors: true,          // 啟用 CORS
  maxInstances: 10,    // 限制最大執行個體以控制成本
  timeoutSeconds: 15,  // 請求逾時時間
}, async (req, res) => {
  const targetUrl = req.query.url;
  if (!targetUrl) {
    res.status(400).send("Missing target URL ('url' query parameter)");
    return;
  }

  try {
    const decodedUrl = decodeURIComponent(targetUrl);
    
    // 安全檢查：必須為網路連結
    if (!decodedUrl.startsWith("http://") && !decodedUrl.startsWith("https://")) {
      res.status(400).send("Invalid target URL format (must be HTTP or HTTPS)");
      return;
    }

    // 發送代理請求
    const response = await fetch(decodedUrl, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) PAWLINK-CORS-Proxy/1.0",
      },
    });

    if (!response.ok) {
      res.status(response.status).send(`Failed to fetch target resource: ${response.statusText}`);
      return;
    }

    // 取得 Content-Type，確保圖片以原始格式呈現 (e.g. image/jpeg, image/png)
    const contentType = response.headers.get("content-type");
    if (contentType) {
      res.setHeader("Content-Type", contentType);
    }

    // 設定快取，使 Hosting Edge 節點與瀏覽器能重複利用，提升性能並節省流量費用 (快取 1 天)
    res.setHeader("Cache-Control", "public, max-age=86400, s-maxage=86400");
    res.setHeader("Access-Control-Allow-Origin", "*");

    // 轉換為 ArrayBuffer 並發送
    const arrayBuffer = await response.arrayBuffer();
    res.send(Buffer.from(arrayBuffer));
  } catch (error) {
    logger.error("CORS Proxy error:", error);
    res.status(500).send("Internal server error fetching target resource");
  }
});
