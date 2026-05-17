import os
import sys

def main():
    if len(sys.argv) < 2 or sys.argv[1].lower() not in ["local", "remote"]:
        print("Usage: python scripts/toggle_chapter_names.py [local|remote]")
        sys.exit(1)

    target_mode = sys.argv[1].lower()

    # Define paths
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    kb_path = os.path.join(base_dir, "assets", "ai_logic", "knowledge", "core_knowledge_base.md")
    persona_path = os.path.join(base_dir, "assets", "ai_logic", "persona", "communicator_v1.md")

    if not os.path.exists(kb_path) or not os.path.exists(persona_path):
        print("Error: Required files not found!")
        sys.exit(1)

    # 1. Read files
    with open(kb_path, "r", encoding="utf-8") as f:
        kb_content = f.read()
    with open(persona_path, "r", encoding="utf-8") as f:
        persona_content = f.read()

    # 2. Self-Detect current mode
    if "第一本書文獻" in kb_content:
        current_mode = "local"
    elif "基礎感知與心靈共振理論" in kb_content:
        current_mode = "remote"
    else:
        # Fallback if mixed/unknown
        current_mode = "unknown"

    print(f"Detected current mode: {current_mode.upper()}")

    if target_mode == current_mode:
        print(f"Workspace is already in {target_mode.upper()} mode. No changes needed.")
        sys.exit(0)

    # 3. Define mapping tables (Original/Local, Target/Remote)
    # TOC & Base structures
    base_structures = [
        ("第一本書文獻", "基礎感知與心靈共振理論"),
        ("第二本書文獻", "高階潛意識感知與心靈共振更新"),
        ("第一章：歡迎來到寵物溝通的世界", "潛意識感應理論與臨床實踐"),
        ("第一章：直覺溝通的本質與學習心態", "直覺溝通的本質與心態奠基"),
        ("第二章：開啟你沉睡已久的感應天線", "直覺感應機制與社會化背景"),
        ("第三章：傳送與接收訊息、心像、感覺", "意念傳送與直覺接收機制"),
        ("第四章：有多準？驗證你的準確度", "直覺感知準確度驗證與協商"),
        ("第五章：寵物真的聽得懂我的話嗎？", "動物理解力與平等協商模型"),
        ("第六章：接收訊息時的基本技巧", "訊息接收的基本共振技巧"),
        ("第七章：相信自己！清除溝通的障礙", "清除認知障礙與信念重建"),
        ("第八章：訊息接收能力再提升", "專注引導與深層信號接收提升"),
        ("第九章：怎麼問才能聊出好交情", "深度探問與關係建立問診"),
        ("第十章：哪些話題最適合跟寵物聊？", "心靈溝通對話範疇引導"),
        ("第十一章：探問寵物的過去身世與心靈療癒", "寵物身世探問與心靈創傷修復"),
        ("第十二章：醫療直覺感應與身心共振療癒", "生理狀態感應與移情共振療癒"),
        ("第十三章：走失寵物協尋與潛意識空間引導", "走失尋回與潛意識協尋空間導航"),
    ]

    # TOC Anchors
    toc_anchors = [
        ("#第一本書文獻", "#基礎感知與心靈共振理論"),
        ("#r-理論-book-001-第一章直覺溝通的本質與學習心態", "#r-理論-book-001-直覺溝通的本質與心態奠基"),
        ("#r-理論-book-001-第二章直覺能力的生理與社會化背景", "#r-理論-book-001-直覺感應機制與社會化背景"),
        ("#r-規範-book-001-直覺溝通的特性與傳送技術", "#r-規範-book-001-意念傳送與直覺接收機制"),
        ("#r-規範-book-001-準確度的驗證與協商模型", "#r-規範-book-001-直覺感知準確度驗證與協商"),
        ("#r-理論-book-001-動物的理解力與平等協商", "#r-理論-book-001-動物理解力與平等協商模型"),
        ("#r-規範-book-001-第六章接收訊息時的基本技巧", "#r-規範-book-001-訊息接收的基本共振技巧"),
        ("#r-理論-規範-book-001-第七章相信自己清除溝通的障礙", "#r-理論-規範-book-001-清除認知障礙與信念重建"),
        ("#r-理論-規範-book-001-第八章訊息接收能力再提升", "#r-理論-規範-book-001-專注引導與深層信號接收提升"),
        ("#r-理論-規範-book-001-第九章怎麼問才能聊出好交情", "#r-理論-規範-book-001-深度探問與關係建立問診"),
        ("#r-理論-規範-book-001-第十章哪些話題最適合跟寵物聊", "#r-理論-規範-book-001-心靈溝通對話範疇引導"),
        ("#r-理論-規範-book-001-第十一章探問寵物的過去身世與心靈療癒", "#r-理論-規範-book-001-寵物身世探問與心靈創傷修復"),
        ("#r-理論-規範-book-001-第十二章醫療直覺感應與身心共振療癒", "#r-理論-規範-book-001-生理狀態感應與移情共振療癒"),
        ("#r-理論-規範-book-001-第十三章走失寵物協尋與潛意識空間引導", "#r-理論-規範-book-001-走失尋回與潛意識協尋空間導航"),
        ("#第二本書文獻", "#高階潛意識感知與心靈共振更新"),
        ("#第一章歡迎來到寵物溝通的世界", "#潛意識感應理論與臨床實踐"),
    ]

    # Body Headers for Book 1
    body_headers_b1 = [
        ("## 第一本書文獻", "## 基礎感知與心靈共振理論"),
        ("## 第二本書文獻", "## 高階潛意識感知與心靈共振更新"),
        ("## 第一章：歡迎來到寵物溝通的世界", "## 潛意識感應理論與臨床實踐"),
        ("### [R] [理論] [book-001] 第一章：直覺溝通的本質與學習心態", "### [R] [理論] [book-001] 直覺溝通的本質與心態奠基"),
        ("### [R] [理論] [book-001] 第二章：直覺能力的生理與社會化背景", "### [R] [理論] [book-001] 直覺感應機制與社會化背景"),
        ("### [R] [規範] [book-001] 第三章：直覺溝通的特性與傳送技術", "### [R] [規範] [book-001] 意念傳送與直覺接收機制"),
        ("### [R] [規範] [book-001] 第四章：準確度的驗證與協商模型", "### [R] [規範] [book-001] 直覺感知準確度驗證與協商"),
        ("### [R] [理論] [book-001] 第五章：動物的理解力與平等協商", "### [R] [理論] [book-001] 動物理解力與平等協商模型"),
        ("### [R] [規範] [book-001] 第六章：接收訊息時的基本技巧", "### [R] [規範] [book-001] 訊息接收的基本共振技巧"),
        ("### [R] [理論] [規範] [book-001] 第七章：相信自己！清除溝通的障礙", "### [R] [理論] [規範] [book-001] 清除認知障礙與信念重建"),
        ("### [R] [理論] [規範] [book-001] 第八章：訊息接收能力再提升", "### [R] [理論] [規範] [book-001] 專注引導與深層信號接收提升"),
        ("### [R] [理論] [規範] [book-001] 第九章：怎麼問才能聊出好交情", "### [R] [理論] [規範] [book-001] 深度探問與關係建立問診"),
        ("### [R] [理論] [規範] [book-001] 第十章：哪些話題最適合跟寵物聊？", "### [R] [理論] [規範] [book-001] 心靈溝通對話範疇引導"),
        ("### [R] [理論] [規範] [book-001] 第十一章：探問寵物的過去身世與心靈療癒", "### [R] [理論] [規範] [book-001] 寵物身世探問與心靈創傷修復"),
        ("### [R] [理論] [規範] [book-001] 第十二章：醫療直覺感應與身心共振療癒", "### [R] [理論] [規範] [book-001] 生理狀態感應與移情共振療癒"),
        ("### [R] [理論] [規範] [book-001] 第十三章：走失寵物協尋與潛意識空間引導", "### [R] [理論] [規範] [book-001] 走失尋回與潛意識協尋空間導航"),
    ]

    # Body Subheaders for Book 2
    body_subheaders_b2 = [
        ("### [R] [理論] [規範] [book-002] 第一章：動物溝通的三種進行模式", "### [R] [理論] [規範] [book-002] 動物溝通的三種進行模式"),
        ("### [R] [理論] [規範] [book-002] 第一章：動物溝通的兩大服務方式與會談哲學", "### [R] [理論] [規範] [book-002] 動物溝通的兩大服務方式與會談哲學"),
        ("### [R] [規範] [book-002] 第一章：完整的動物溝通實務流程與品質指標", "### [R] [規範] [book-002] 完整的動物溝通實務流程與品質指標"),
        ("### [R] [理論] [規範] [book-002] 第一章：挑選優秀動物溝通師的四大指標與溝通本質", "### [R] [理論] [規範] [book-002] 挑選優秀動物溝通師的四大指標與溝通本質"),
        ("### [R] [案例] [book-002] 第一章：失蹤協尋實務案例（黑白米克斯犬田野迷航案）", "### [R] [案例] [book-002] 失蹤協尋實務案例（黑白米克斯犬田野迷航案）"),
        ("### [R] [理論] [book-002] 第一章：類科學體系與量子物理模型之邊界與解讀 [S]", "### [R] [理論] [book-002] 類科學體系與量子物理模型之邊界與解讀 [S]"),
        ("### [R] [理論] [book-002] 第一章：靈性與通靈流派之步驟、間接溝通分類與安全警示 [S]", "### [R] [理論] [book-002] 靈性與通靈流派之步驟、間接溝通分類與安全警示 [S]"),
        ("### [R] [理論] [book-002] 第一章：文明演進、超心理學爭議與松果體圖騰之文化象徵 [S]", "### [R] [理論] [book-002] 文明演進、超心理學爭議與松果體圖騰之文化象徵 [S]"),
        ("### [R] [理論] [book-002] 第一章：松果體之感光機制、笛卡兒「靈魂之座」與黑暗靜心法", "### [R] [理論] [book-002] 松果體之感光機制、笛卡兒「靈魂之座」與黑暗靜心法"),
        ("### [R] [理論] [book-002] 第一章：精神分子 DMT 與死藤水之藥理效用與安全防線 [S]", "### [R] [理論] [book-002] 精神分子 DMT 與死藤水之藥理效用與安全防線 [S]"),
        ("### [R] [理論] [book-002] 第一章：心理派動物溝通的學理定位與高度心理學演進", "### [R] [理論] [book-002] 心理派動物溝通的學理定位與高度心理學演進"),
        ("### [R] [理論] [book-002] 第一章：心理綜合學派「意識蛋形圖」之完整結構解讀 [S]", "### [R] [理論] [book-002] 心理綜合學派「意識蛋形圖」之完整結構解讀 [S]"),
        ("### [R] [理論] [規範] [book-002] 第一章：停下紛擾之靜心學理與催眠東方化探索", "### [R] [理論] [規範] [book-002] 停下紛擾之靜心學理與催眠東方化探索"),
        ("### [R] [理論] [規範] [book-002] 第一章：極靜生慧之直覺力開發與無作為感知字庫 [S]", "### [R] [理論] [規範] [book-002] 極靜生慧之直覺力開發與無作為感知字庫 [S]"),
        ("### [R] [理論] [book-002] 第一章：fMRI 腦定位與 EEG 腦電圖分型之科學實證", "### [R] [理論] [book-002] fMRI 腦定位與 EEG 腦電圖分型之科學實證"),
        ("### [R] [理論] [book-002] 第一章：人類心靈智力的光譜演進：IQ、EQ 與 SQ 的提出", "### [R] [理論] [book-002] 人類心靈智力的光譜演進：IQ、EQ 與 SQ 的提出"),
        ("### [R] [理論] [規範] [book-002] 第一章：直接溝通與間接溝通之核心界定與機制解密 [S]", "### [R] [理論] [規範] [book-002] 直接溝通與間接溝通之核心界定與機制解密 [S]"),
    ]

    # Paragraph references
    paragraph_refs = [
        ("本書後續章節/第五章專章討論", "後續走失定位機制專章討論"),
        ("第八章的 Theta 腦波專注", "「專注引導與深層信號接收提升」主題的 Theta 腦波專注"),
        ("第八章的專注/接地靜心步驟", "「專注引導與深層信號接收提升」主題的專注/接地靜心步驟"),
        ("第七章的應對焦慮與正向增強", "「清除認知障礙與信念重建」主題的應對焦慮與正向增強"),
        ("細節詳見第三章", "細節詳見意念傳送與直覺接收技術"),
    ]

    # Persona file replacements
    persona_refs = [
        ("(Chapter 8)", "(信號提升規約)"),
        ("(Chapter 7)", "(信念重建規約)"),
    ]

    # 4. Perform Switch
    if target_mode == "remote":
        print("Switching workspace to REMOTE mode (Scrubbed chapter names for production)...")
        # Apply forward replacements
        for original, target in base_structures:
            kb_content = kb_content.replace(original, target)
        for original, target in toc_anchors:
            kb_content = kb_content.replace(original, target)
        for original, target in body_headers_b1:
            kb_content = kb_content.replace(original, target)
        for original, target in body_subheaders_b2:
            kb_content = kb_content.replace(original, target)
        for original, target in paragraph_refs:
            kb_content = kb_content.replace(original, target)
        for original, target in persona_refs:
            persona_content = persona_content.replace(original, target)

    elif target_mode == "local":
        print("Switching workspace to LOCAL mode (Restored chapter names for development)...")
        # Apply reverse replacements (target -> original)
        for original, target in base_structures:
            kb_content = kb_content.replace(target, original)
        for original, target in toc_anchors:
            kb_content = kb_content.replace(target, original)
        for original, target in body_headers_b1:
            kb_content = kb_content.replace(target, original)
        for original, target in body_subheaders_b2:
            kb_content = kb_content.replace(target, original)
        for original, target in paragraph_refs:
            kb_content = kb_content.replace(target, original)
        for original, target in persona_refs:
            persona_content = persona_content.replace(target, original)

    # 5. Write back
    with open(kb_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(kb_content)
    with open(persona_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(persona_content)

    print(f"Successfully switched to {target_mode.upper()} mode!")

if __name__ == "__main__":
    main()
