import subprocess
import os

cwd = r"C:\Users\s2230\.gemini\antigravity-ide\scratch\ai-pet-communication"

try:
    # Run git log --all --grep or search using git log -S
    output = subprocess.check_output(["git", "log", "--all", "-S", "放下關注周遭的目光", "--oneline"], cwd=cwd).decode('utf-8', errors='ignore')
    print("Commits with keyword:")
    print(output)
    
    # Or search all files in the current commit
    print("\nSearching current directory for the keyword...")
    for root, dirs, files in os.walk(cwd):
        if ".git" in root or ".dart_tool" in root or "build" in root:
            continue
        for file in files:
            file_path = os.path.join(root, file)
            try:
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    if "放下關注周遭的目光" in content:
                        print("Found in file:", file_path)
            except Exception as e:
                pass
except Exception as e:
    print("Error:", e)
