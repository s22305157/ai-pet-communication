import os

def rename_terms(file_path):
    if not os.path.exists(file_path):
        print(f"Error: File {file_path} not found!")
        return False
        
    print(f"Processing file: {file_path}")
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()
        
    original_len = len(content)
    
    # Perform replacements
    content = content.replace("第一本書文獻", "文獻一")
    content = content.replace("第二本書文獻", "文獻二")
    content = content.replace("book-001", "Doc-001")
    content = content.replace("book-002", "Doc-002")
    
    # Also handle possible variations in casing just in case
    content = content.replace("Book-001", "Doc-001")
    content = content.replace("Book-002", "Doc-002")
    
    with open(file_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)
        
    print(f"Successfully processed {file_path} (length: {original_len} -> {len(content)})")
    return True

def main():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    files_to_process = [
        os.path.join(base_dir, "assets", "ai_logic", "knowledge", "core_knowledge_base.md"),
        os.path.join(base_dir, "assets", "ai_logic", "persona", "communicator_v1.md"),
        os.path.join(base_dir, "scripts", "toggle_chapter_names.py"),
    ]
    
    for file_path in files_to_process:
        rename_terms(file_path)

if __name__ == "__main__":
    main()
