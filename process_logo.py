import cv2
import numpy as np
import os

img_path = r'c:\Users\s2230\.gemini\antigravity\scratch\ai-pet-communication\assets\logo.png'
img = cv2.imread(img_path, cv2.IMREAD_UNCHANGED)

if img.shape[2] == 3:
    img = cv2.cvtColor(img, cv2.COLOR_BGR2BGRA)

h, w = img.shape[:2]

# 1. 處理去背 (白底、淡藍底)
for y in range(h):
    for x in range(w):
        b, g, r, a = img[y, x]
        if b > 230 and g > 230 and r > 230:
            img[y, x, 3] = 0

# 2. 移除文字區塊 (底部 35%)
clear_height = int(h * 0.65)
img[clear_height:, :, 3] = 0

# 3. 找出圖標的精確邊界
alpha = img[:, :, 3]
y_indices, x_indices = np.where(alpha > 0)

if len(x_indices) > 0:
    x_min, x_max = np.min(x_indices), np.max(x_indices)
    y_min, y_max = np.min(y_indices), np.max(y_indices)
    
    # 裁切出純圖標
    logo_part = img[y_min:y_max+1, x_min:x_max+1]
    
    # 4. 建立一個正方形的透明底圖，將圖標置中放置
    logo_h, logo_w = logo_part.shape[:2]
    side = max(logo_h, logo_w) + 20 # 增加一些邊距
    
    centered_img = np.zeros((side, side, 4), dtype=np.uint8)
    
    # 計算放置位置
    y_offset = (side - logo_h) // 2
    x_offset = (side - logo_w) // 2
    
    centered_img[y_offset:y_offset+logo_h, x_offset:x_offset+logo_w] = logo_part
    final_img = centered_img
else:
    final_img = img

out_path = r'c:\Users\s2230\.gemini\antigravity\scratch\ai-pet-communication\assets\logo_pure.png'
cv2.imwrite(out_path, final_img)

# 同步更新到 brain 目錄供預覽
brain_path = r'C:\Users\s2230\.gemini\antigravity\brain\1e3148e0-46ff-4345-a660-b7e4203580c0\logo_icon_only.png'
cv2.imwrite(brain_path, final_img)

print("Logo processed and mathematically centered.")
