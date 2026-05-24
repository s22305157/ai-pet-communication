import os

file_path = r"C:\Users\s2230\.gemini\antigravity-ide\scratch\ai-pet-communication\assets\ai_logic/knowledge/core_knowledge_base.md"
output_path = r"C:\Users\s2230\.gemini\antigravity-ide\scratch\ai-pet-communication\scratch\view_output.txt"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

start = 1175
end = min(1275, len(lines))

with open(output_path, 'w', encoding='utf-8') as out:
    for idx in range(start, end):
        out.write(f"{idx+1}: {lines[idx]}")

print("Wrote lines to scratch/view_output.txt")
