#!/usr/bin/env python3
"""Looks for secrets in the files Git tracks (audit.py runs it: a hit blocks the commit) or in any folder (publish.sh).

Patterns: a Google API key, an OpenAI-style key, a PEM private key header, a password literal. A tracked Secrets.plist
(the file that holds the Gemini key) is an error by itself.
Usage: python3 Tools/secrets_scan.py [folder]      no argument: the tracked files of the repository
"""
from __future__ import annotations

import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATTERNS = {
    "Google API key": re.compile(r"AIza[0-9A-Za-z_\-]{35}"),
    "API key (sk-)": re.compile(r"\bsk-[A-Za-z0-9_\-]{20,}"),
    "private key": re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY"),
    "password literal": re.compile(r"""password\s*[=:]\s*["'][^"'\s]{3,}["']""", re.I),
}


def scan_file(path: str, shown: str) -> list[str]:
    try:
        text = open(path, encoding="utf-8").read()
    except (OSError, UnicodeDecodeError):
        return []  # binary or unreadable
    hits = []
    for name, pattern in PATTERNS.items():
        for match in pattern.finditer(text):
            hits.append(f"secret ({name})  {shown}:{text[:match.start()].count(chr(10)) + 1}")
    return hits


def tracked_files() -> list[str]:
    out = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True, text=True).stdout
    return [line for line in out.splitlines() if line]


def scan_repository() -> list[str]:
    files = tracked_files()
    issues = [f"secret file tracked by Git  {f}" for f in files if os.path.basename(f) == "Secrets.plist"]
    for f in files:
        if os.path.isfile(os.path.join(ROOT, f)):
            issues += scan_file(os.path.join(ROOT, f), f)
    return issues


def scan_folder(folder: str) -> list[str]:
    issues = []
    for base, dirs, names in os.walk(folder):
        dirs[:] = [d for d in dirs if d != ".git"]
        for name in names:
            path = os.path.join(base, name)
            rel = os.path.relpath(path, folder)
            if name == "Secrets.plist":
                issues.append(f"secret file present  {rel}")
            issues += scan_file(path, rel)
    return issues


if __name__ == "__main__":
    found = scan_folder(sys.argv[1]) if len(sys.argv) > 1 else scan_repository()
    print("\n".join(found) if found else "secrets: clean")
    sys.exit(1 if found else 0)
