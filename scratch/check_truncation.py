import json
import os

transcript_path = r"C:\Users\s2230\.gemini\antigravity\brain\da1349f7-6bee-4160-8278-e62dc094c692\.system_generated\logs\transcript.jsonl"

with open(transcript_path, 'r', encoding='utf-8') as f:
    for line in f:
        try:
            data = json.loads(line)
            content = data.get('content', '')
            if '放下關注周遭的目光' in content:
                print("Step 1 text found:")
                print("Is truncated in content field?", "<truncated" in content)
                # Print the length of content
                print("Length of content:", len(content))
                # Print the content with first 200 chars and last 200 chars
                print("START:", content[:400])
                print("END:", content[-400:])
        except Exception as e:
            pass
