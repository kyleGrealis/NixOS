#!/usr/bin/env python3
import os
import sys
from datetime import datetime

VAULT_DIR = "/home/kyle/Documents/obsidian"
DAILY_NOTES_DIR = os.path.join(VAULT_DIR, "Daily Notes")
WORK_DIR = os.path.join(VAULT_DIR, "Work")
WORK_TAGS = {"#galindo", "#m2", "#vibe", "#ctn", "#ray", "#nhanes", "#nhanesdata"}

def get_tasks(simulated_date_str=None):
    if simulated_date_str:
        try:
            today = datetime.strptime(simulated_date_str, "%Y-%m-%d")
        except ValueError:
            today = datetime.now()
    else:
        today = datetime.now()
        
    is_weekend = today.weekday() in (5, 6) # 5=Saturday, 6=Sunday
    
    # Exclude today's note
    today_filename_part1 = today.strftime("%B %d, %Y")
    today_filename_part2 = today_filename_part1.replace(" 0", " ")
    today_filenames = {today_filename_part1.lower(), today_filename_part2.lower()}
    
    personal_todos = []
    work_todos = []
    
    # 1. Parse Daily Notes
    if os.path.isdir(DAILY_NOTES_DIR):
        for root, dirs, files in os.walk(DAILY_NOTES_DIR):
            for file in files:
                if not file.endswith(".md"):
                    continue
                base_name = os.path.splitext(file)[0].lower()
                if base_name in today_filenames:
                    continue
                    
                file_path = os.path.join(root, file)
                try:
                    with open(file_path, "r", encoding="utf-8") as f:
                        lines = f.readlines()
                except Exception:
                    continue
                    
                current_heading = None
                for line in lines:
                    stripped = line.strip()
                    if stripped.startswith("#### "):
                        current_heading = stripped[5:].strip().lower()
                        continue
                    elif stripped.startswith("### "):
                        current_heading = stripped[4:].strip().lower()
                        continue
                    elif stripped.startswith("## "):
                        current_heading = stripped[3:].strip().lower()
                        continue
                    elif stripped.startswith("# "):
                        current_heading = stripped[2:].strip().lower()
                        continue
                    
                    if (line.startswith("- [ ]") or line.startswith("* [ ]")) and not line.startswith("\t") and not line.startswith(" "):
                        task_text = line[5:].strip()
                        if not task_text:
                            continue
                        # Never include Daily Habits
                        if current_heading and "daily habit" in current_heading:
                            continue
                        if current_heading and "personal todo" in current_heading:
                            personal_todos.append(task_text)
                        elif current_heading and "work todo" in current_heading:
                            work_todos.append(task_text)
                
    # 2. Parse Work Directory
    if os.path.isdir(WORK_DIR):
        for root, dirs, files in os.walk(WORK_DIR):
            for file in files:
                if not file.endswith(".md"):
                    continue
                file_path = os.path.join(root, file)
                try:
                    with open(file_path, "r", encoding="utf-8") as f:
                        lines = f.readlines()
                except Exception:
                    continue
                    
                for line in lines:
                    if (line.startswith("- [ ]") or line.startswith("* [ ]")) and not line.startswith("\t") and not line.startswith(" "):
                        task_text = line[5:].strip()
                        if task_text:
                            work_todos.append(task_text)
                            
    # 3. Parse whole vault for Tag-based Work tasks
    if os.path.isdir(VAULT_DIR):
        for root, dirs, files in os.walk(VAULT_DIR):
            if "Daily Notes" in root or "Work" in root:
                continue
            for file in files:
                if not file.endswith(".md"):
                    continue
                file_path = os.path.join(root, file)
                try:
                    with open(file_path, "r", encoding="utf-8") as f:
                        lines = f.readlines()
                except Exception:
                    continue
                    
                for line in lines:
                    if (line.startswith("- [ ]") or line.startswith("* [ ]")) and not line.startswith("\t") and not line.startswith(" "):
                        task_text = line[5:].strip()
                        if task_text:
                            has_tag = any(tag in task_text.lower() for tag in WORK_TAGS)
                            if has_tag:
                                work_todos.append(task_text)
                                
    # Remove duplicates but keep order
    personal_todos = list(dict.fromkeys(personal_todos))
    work_todos = list(dict.fromkeys(work_todos))
    
    # Weekend Gating
    if is_weekend:
        work_todos = []
        
    return personal_todos, work_todos

if __name__ == "__main__":
    sim_date = sys.argv[1] if len(sys.argv) > 1 else None
    personal, work = get_tasks(sim_date)
    
    print("PERSONAL:")
    for t in personal:
        print(f"- [ ] {t}")
    print("\nWORK:")
    for t in work:
        print(f"- [ ] {t}")
