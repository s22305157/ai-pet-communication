import os

file_path = r"C:\Users\s2230\.gemini\antigravity-ide\scratch\ai-pet-communication\assets\ai_logic/knowledge/core_knowledge_base.md"

if not os.path.exists(file_path):
    print("File not found:", file_path)
    exit(1)

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

print("Total lines:", len(lines))
# print lines 1180 to 1270 (0-indexed: 1179 to 1269)
start = 1179
end = min(1269, len(lines))
for idx in range(start, end):
    print(f"{idx+1}: {lines[idx]}", end="")
