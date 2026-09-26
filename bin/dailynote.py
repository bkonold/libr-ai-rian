#!/usr/bin/env python3
"""Deterministic edits to a daily note. No model involved.

  dailynote.py extract NOTE H2 H3          print the bullet lines under '## H2' / '### H3'; exit 3 if that heading is missing
  dailynote.py clear   NOTE H2 H3 [TEXT]   replace that section's body with TEXT (or empty)
  dailynote.py filed   NOTE LINE...        append LINEs under '## Filed' (created if missing)
  dailynote.py new     TEMPLATE NOTE DATE  write NOTE from TEMPLATE with {{date:YYYY-MM-DD}} filled in
"""
import os
import sys


def load(path):
    with open(path, encoding="utf-8") as f:
        return f.read().split("\n")


def save(path, lines):
    text = "\n".join(lines).rstrip("\n") + "\n"
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


def section(lines, h2, h3):
    """(start, end) of the body under '### h3' inside '## h2', or None."""
    in_h2 = False
    for i, line in enumerate(lines):
        s = line.strip()
        if s.startswith("## ") and not s.startswith("### "):
            in_h2 = s == f"## {h2}"
        elif in_h2 and s == f"### {h3}":
            j = i + 1
            while j < len(lines) and not lines[j].startswith("## ") and not lines[j].startswith("### "):
                j += 1
            return i + 1, j
    return None


def main():
    cmd = sys.argv[1]
    if cmd == "new":
        tmpl, note, date = sys.argv[2:5]
        if os.path.exists(note):
            return
        os.makedirs(os.path.dirname(note), exist_ok=True)
        with open(tmpl, encoding="utf-8") as f:
            # {{date:YYYY-MM-DD}} is Obsidian's own template variable, so a note the
            # phone creates first comes out identical; {{DATE}} is the older template.
            body = f.read().replace("{{date:YYYY-MM-DD}}", date).replace("{{DATE}}", date)
        with open(note, "w", encoding="utf-8") as f:
            f.write(body)
        return

    note = sys.argv[2]
    lines = load(note)

    if cmd == "extract":
        r = section(lines, sys.argv[3], sys.argv[4])
        if r is None:
            sys.exit(3)                   # heading missing (template changed?); empty is exit 0
        body = [l for l in lines[r[0]:r[1]] if l.strip() not in ("", "-")]
        if body:                          # an empty section prints nothing, not a blank line
            print("\n".join(body))
    elif cmd == "clear":
        r = section(lines, sys.argv[3], sys.argv[4])
        if r:
            text = sys.argv[5] if len(sys.argv) > 5 else ""
            lines[r[0]:r[1]] = ([text] if text else []) + [""]
            save(note, lines)
    elif cmd == "filed":
        items = sys.argv[3:]
        idx = next((i for i, l in enumerate(lines) if l.strip() == "## Filed"), None)
        if idx is None:
            lines += ["", "## Filed"]
            idx = len(lines) - 1
        j = idx + 1
        while j < len(lines) and not lines[j].startswith("## "):
            j += 1
        while j > idx + 1 and lines[j - 1].strip() == "":
            j -= 1
        lines[j:j] = items
        save(note, lines)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
