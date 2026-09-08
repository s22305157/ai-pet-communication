import json
import os

transcript_path = r"C:\Users\s2230\.gemini\antigravity\brain\da1349f7-6bee-4160-8278-e62dc094c692\.system_generated\logs\transcript.jsonl"

with open(transcript_path, 'r', encoding='utf-8') as f:
    for line in f:
        if '第一步——先創造停止點' in line:
            print("FOUND LINE LENGTH:", len(line))
            # parse as json and check keys
            try:
                data = json.loads(line)
                print("KEYS:", list(data.keys()))
                print("CONTENT TYPE:", type(data.get('content')))
                # Write raw content to a file to verify if it has '<truncated>'
                with open(r"C:\Users\s2230\.gemini\antigravity-ide\scratch\ai-pet-communication\scratch\raw_line_found.txt", 'w', encoding='utf-8') as out:
                    out.write(line)
                print("Wrote raw line to scratch/raw_line_found.txt")
            except Exception as e:
                print("JSON Error:", e)
