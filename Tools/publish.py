#!/usr/bin/env python3
"""Exports HEAD to a folder fit for a public repository: no history, personal data replaced, secrets scanned.

Steps (in a temporary folder; nothing is written to the destination unless every step passes):
1. `git archive HEAD` (tracked files only, so no Secrets.plist, no Tools/.data).
2. Every rule of Tools/publish_redact.txt is applied to every text file; a `forbid:` pattern still found afterwards fails.
3. Tools/secrets_scan.py on the result; then docs/index.html is rebuilt with Tools/doc.py.
4. The folder is moved to the destination. Pushing it is up to the user: this script never does.
Rules file (private, ignored by Git because it lists the personal data itself): see Tools/publish_redact.example.txt.
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RULES = os.path.join(ROOT, "Tools", "publish_redact.txt")


def load_rules() -> tuple[list[tuple[re.Pattern, str]], list[re.Pattern]]:
    replace, forbid = [], []
    for line in open(RULES, encoding="utf-8").read().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("forbid:"):
            forbid.append(re.compile(line[len("forbid:"):].strip()))
        elif " => " in line:
            pattern, _, replacement = line.partition(" => ")
            replace.append((re.compile(pattern.strip()), replacement.strip()))
        else:
            sys.exit(f"publish: unreadable rule: {line}")
    return replace, forbid


def fail(message: str) -> None:
    sys.exit(f"publish: {message}. Nothing was produced.")


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit("usage: zsh Tools/publish.sh <new-or-empty-folder>")
    dest = os.path.abspath(sys.argv[1])
    if dest == ROOT or dest.startswith(ROOT + os.sep):
        fail("the destination must be outside the project")
    if os.path.exists(dest) and os.listdir(dest):
        fail(f"{dest} is not empty")
    if not os.path.exists(RULES):
        fail("Tools/publish_redact.txt is missing (copy Tools/publish_redact.example.txt and fill it)")
    replace, forbid = load_rules()

    work = tempfile.mkdtemp(prefix="hexis-public-")
    try:
        archive = subprocess.run(f"git -C '{ROOT}' archive HEAD | tar -x -C '{work}'", shell=True)
        if archive.returncode != 0:
            fail("git archive failed")
        left = []
        for base, dirs, names in os.walk(work):
            for name in names:
                path = os.path.join(base, name)
                try:
                    text = open(path, encoding="utf-8").read()
                except (UnicodeDecodeError, OSError):
                    continue  # binary file
                new = text
                for pattern, replacement in replace:
                    new = pattern.sub(replacement, new)
                if new != text:
                    open(path, "w", encoding="utf-8").write(new)
                for pattern in forbid:
                    if pattern.search(new):
                        left.append(f"{os.path.relpath(path, work)}  (/{pattern.pattern}/)")
        if left:
            fail("personal data still present:\n  " + "\n  ".join(left[:20]))
        sys.path.insert(0, os.path.join(ROOT, "Tools"))
        import secrets_scan
        leaks = secrets_scan.scan_folder(work)
        if leaks:
            fail("secrets found:\n  " + "\n  ".join(leaks[:20]))
        rebuilt = subprocess.run([sys.executable, os.path.join(work, "Tools", "doc.py")], cwd=work, capture_output=True, text=True)
        if rebuilt.returncode != 0:
            fail("doc.py failed: " + rebuilt.stderr[-300:])
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        if os.path.exists(dest):
            os.rmdir(dest)
        shutil.move(work, dest)
        print(f"public snapshot ready in {dest} (no history; push it yourself)")
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
