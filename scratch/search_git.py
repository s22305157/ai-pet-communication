import subprocess
import os

cwd = r"C:\Users\s2230\.gemini\antigravity-ide\scratch\ai-pet-communication"
output_path = r"C:\Users\s2230\.gemini\antigravity-ide\scratch\ai-pet-communication\scratch\git_search_results.txt"

try:
    commits = subprocess.check_output(["git", "log", "--format=%H", "assets/ai_logic/knowledge/core_knowledge_base.md"], cwd=cwd).decode('utf-8', errors='ignore').splitlines()
    print("Found commits modifying the file:", len(commits))
    
    with open(output_path, 'w', encoding='utf-8') as out_f:
        for commit in commits:
            try:
                # Set encryption key environment variable when running git show just in case
                env = os.environ.copy()
                env["KB_ENCRYPTION_KEY"] = "yjAD1Kl6e0DuWsAidENw2p4JO6r7WqiE4E1uaE0vwWo="
                content = subprocess.check_output(["git", "show", f"{commit}:assets/ai_logic/knowledge/core_knowledge_base.md"], cwd=cwd, env=env).decode('utf-8', errors='ignore')
                if "放下關注周遭的目光" in content:
                    out_f.write(f"=== Commit {commit} contains '放下關注周遭的目光' ===\n")
                    lines = content.splitlines()
                    for idx, line in enumerate(lines):
                        if "#### 1、" in line or "放下關注周遭的目光" in line:
                            out_f.write(f"Line {idx}: {line}\n")
                            for offset in range(1, 120):
                                if idx + offset < len(lines):
                                    out_f.write(lines[idx + offset] + "\n")
                            break
                    out_f.write("\n===================================\n\n")
            except Exception as e:
                out_f.write(f"Error on commit {commit}: {e}\n")
    print("Search complete. Results written to:", output_path)
except Exception as e:
    print("Outer Error:", e)
