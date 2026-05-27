#!/usr/bin/env python3
"""Automate marking a task done.
Removes the task block from ai/TASKS.md and appends it to ai/DONE_LOG.md.
Usage: python3 scripts/mark-task-done.py <TASK-ID>
Example: python3 scripts/mark-task-done.py P0-T1
"""

import sys
import re
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# Recognize a task heading exactly: "### P<digits>-T<digits>: <title>"
# Used for termination so we don't accidentally end extraction on
# unrelated H3 headings whose text starts with "P" (Performance,
# Prerequisites, Postgres, ...).
TASK_HEADING_RE = re.compile(r"^### P\d+-T\d+:")

# Match a YYYY-MM-DD date heading (ISO date sorts correctly as a string).
DATE_HEADING_RE = re.compile(r"^### (\d{4}-\d{2}-\d{2})\s*$")


def update_last_updated(lines, date_str):
    for i, line in enumerate(lines[:10]):
        if re.match(r"^Last Updated:\s*", line):
            lines[i] = f"Last Updated: {date_str}\n"
            return
    lines.insert(2, f"Last Updated: {date_str}\n\n")


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/mark-task-done.py <TASK-ID>")
        sys.exit(1)

    task_id = sys.argv[1].strip()
    tasks_path = REPO_ROOT / "ai/TASKS.md"
    done_path = REPO_ROOT / "ai/DONE_LOG.md"

    if not tasks_path.exists():
        print(f"Error: {tasks_path} not found.")
        sys.exit(1)

    with open(tasks_path, "r", encoding="utf-8") as f:
        task_lines = f.readlines()

    # Anchor the start match: "### <task_id>:" only at line start.
    start_re = re.compile(rf"^### {re.escape(task_id)}:")
    # Strip the heading prefix from the title using a proper anchored sub.
    title_strip_re = re.compile(rf"^###\s+{re.escape(task_id)}:\s*")

    new_task_lines = []
    in_target_task = False
    task_title = ""

    for line in task_lines:
        if start_re.match(line):
            in_target_task = True
            task_title = title_strip_re.sub("", line).strip()
            continue
        if in_target_task:
            # Stop when we hit ANY next task heading or an H2 section.
            # Use the strict task-heading regex so headings like
            # "### Performance" or "### Prerequisites" inside the task
            # body do not prematurely terminate extraction.
            if TASK_HEADING_RE.match(line) or line.startswith("## "):
                in_target_task = False
            else:
                continue

        new_task_lines.append(line)

    if not task_title:
        print(f"Error: Task {task_id} not found in {tasks_path}")
        sys.exit(1)

    # Clean up excessive newlines
    clean_task_lines = []
    for line in new_task_lines:
        if clean_task_lines and clean_task_lines[-1] == "\n" and line == "\n":
            continue
        clean_task_lines.append(line)

    date_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    update_last_updated(clean_task_lines, date_str)

    with open(tasks_path, "w", encoding="utf-8") as f:
        f.writelines(clean_task_lines)

    # Update DONE_LOG.md
    if done_path.exists():
        with open(done_path, "r", encoding="utf-8") as f:
            done_lines = f.readlines()
    else:
        done_lines = ["# Done Log\n", "\n", f"Last Updated: {date_str}\n", "\n"]

    update_last_updated(done_lines, date_str)

    date_heading = f"### {date_str}\n"
    entry_line = f"- {task_id}: {task_title}\n"

    # Find all existing date headings with their line indices.
    # ISO YYYY-MM-DD sorts lexicographically as a string.
    date_positions = []  # list of (line_index, "YYYY-MM-DD")
    for i, line in enumerate(done_lines):
        m = DATE_HEADING_RE.match(line)
        if m:
            date_positions.append((i, m.group(1)))

    # If today already has a heading, insert the entry right under it.
    today_idx = next((idx for idx, d in date_positions if d == date_str), None)
    if today_idx is not None:
        done_lines.insert(today_idx + 1, entry_line)
    else:
        # Insert a new date heading. Walk existing headings and find the
        # first one that is OLDER than today; insert before it. This keeps
        # the log in newest-first order regardless of any prior misordering.
        insert_idx = len(done_lines)  # default: append at end
        for idx, d in date_positions:
            if d < date_str:
                insert_idx = idx
                break

        # Ensure a blank line separates the new heading from preceding content.
        if insert_idx > 0 and done_lines[insert_idx - 1].strip() != "":
            done_lines.insert(insert_idx, "\n")
            insert_idx += 1

        done_lines.insert(insert_idx, date_heading)
        done_lines.insert(insert_idx + 1, entry_line)

        # If there's content immediately after our new section and it
        # isn't a blank line, add one for readability.
        tail_idx = insert_idx + 2
        if tail_idx < len(done_lines) and done_lines[tail_idx].strip() != "":
            done_lines.insert(tail_idx, "\n")

    with open(done_path, "w", encoding="utf-8") as f:
        f.writelines(done_lines)

    print(f"Successfully marked {task_id} done.")
    print(f"- Removed from TASKS.md")
    print(f"- Appended to DONE_LOG.md: {task_id}: {task_title}")


if __name__ == "__main__":
    main()
