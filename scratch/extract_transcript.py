import json
import os

transcript_path = r"C:\Users\s2230\.gemini\antigravity\brain\da1349f7-6bee-4160-8278-e62dc094c692\.system_generated\logs\transcript.jsonl"
output_path = r"C:\Users\s2230\.gemini\antigravity-ide\scratch\ai-pet-communication\scratch\user_inputs_extracted.txt"

if not os.path.exists(transcript_path):
    print("File not found:", transcript_path)
    exit(1)

extracted = []
with open(transcript_path, 'r', encoding='utf-8') as f:
    for line in f:
        try:
            data = json.loads(line)
            if data.get('type') == 'USER_INPUT':
                content = data.get('content', '')
                if '第一步——先創造停止點' in content or '放下關注周遭的目光' in content:
                    extracted.append(content)
        except Exception as e:
            pass

with open(output_path, 'w', encoding='utf-8') as out_f:
    out_f.write("\n\n=== NEXT USER REQUEST ===\n\n".join(extracted))

print("Successfully wrote to:", output_path)
