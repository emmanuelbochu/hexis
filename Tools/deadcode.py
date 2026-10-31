#!/usr/bin/env python3
"""Finds dead code: Swift declarations whose name is never used elsewhere, exercise images without an exercise,
UserDefaults keys only written or only read, Program.json fields the app never reads.
Also warns about big files and TODO/FIXME. audit.py runs it: dead code blocks the commit, the rest only warns.

Usage: python3 Tools/deadcode.py        (prints errors then warnings)
Allow list: Tools/deadcode_allow.txt, one `name  reason` per line, for names that look unused but are not
(called by the system, by SwiftData, by a protocol); a file stem there silences its big-file warning. Old schemas (SchemaV1..V11) are never reported: migrations need them.
"""
from __future__ import annotations

import glob
import json
import os
import re
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCES = ["Hexis", "HexisWidgets", "HexisShared"]
BIG_FILE = 150
SYSTEM_NAMES = {
    "body", "init", "deinit", "main", "makeBody", "makeUIViewController", "updateUIViewController", "makeUIView",
    "updateUIView", "makeCoordinator", "encode", "hash", "reduce", "defaultValue", "previewValue", "liveValue", "id",
    # delegate callbacks, called by UIKit/CoreLocation
    "imagePickerController", "imagePickerControllerDidCancel", "locationManagerDidChangeAuthorization",
}
DECL = re.compile(
    r"^(?P<indent> *)(?P<attrs>(?:@\w+(?:\([^)]*\))?\s+|(?:private|fileprivate|internal|public|final|static|nonisolated|"
    r"override|mutating|class|indirect)\s+)*)(?P<kind>func|struct|class|enum|protocol|typealias|var|let)\s+(?P<name>\w+)",
    re.M)


def read(path: str) -> str:
    with open(path, encoding="utf-8") as f:
        return f.read()


def swift_paths() -> list[str]:
    paths: list[str] = []
    for sub in SOURCES:
        paths += glob.glob(os.path.join(ROOT, sub, "**", "*.swift"), recursive=True)
    return sorted(paths)


def strip_comments(text: str) -> str:
    return re.sub(r"//.*", "", text)


def allowed() -> set[str]:
    path = os.path.join(ROOT, "Tools", "deadcode_allow.txt")
    if not os.path.exists(path):
        return set()
    return {line.split()[0] for line in read(path).splitlines() if line.strip() and not line.startswith("#")}


def word_counts(texts: list[str]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for text in texts:
        for w in re.findall(r"\b\w+\b", text):
            counts[w] = counts.get(w, 0) + 1
    return counts


def unused_declarations(sources: dict[str, str], allow: set[str]) -> list[str]:
    cleaned = {p: strip_comments(re.sub(r"#Preview.*", "", t, flags=re.S)) for p, t in sources.items()}
    counts = word_counts(list(cleaned.values()))
    found = []
    for path, text in cleaned.items():
        rel = os.path.relpath(path, ROOT)
        if re.search(r"SchemaV\d+\.swift$", path) or "Schema/" in rel:
            continue
        for m in DECL.finditer(text):
            name, kind, attrs, indent = m["name"], m["kind"], m["attrs"] or "", len(m["indent"])
            if name in SYSTEM_NAMES or name in allow or "override" in attrs or "@objc" in attrs or "@main" in attrs or name.startswith("_"):
                continue
            if kind in ("var", "let") and not ("static" in attrs and indent <= 4):
                continue  # instance properties belong to Codable/SwiftData/SwiftUI: only statics are checked
            if kind == "func" and indent > 8:
                continue
            if counts.get(name, 0) <= 1:
                line = text[:m.start()].count("\n") + 1
                found.append(f"dead code  {kind} {name}  ({rel}:{line})")
    return found


def exercise_images() -> list[str]:
    def slug(name: str) -> str:
        folded = "".join(c for c in unicodedata.normalize("NFD", name) if unicodedata.category(c) != "Mn").lower()
        return "exo-" + "-".join(re.findall(r"[^\W_]+", folded))

    program = json.loads(read(os.path.join(ROOT, "Hexis/Resources/Program.json")))
    names = {e["name"] for w in program["workouts"] for b in w["blocks"] for e in b.get("exercises", [])}
    names |= {e["name"] for ph in program.get("rehab", {}).get("phases", []) for e in _walk_exercises(ph)}
    wanted = {slug(n) for n in names}
    out = []
    for path in glob.glob(os.path.join(ROOT, "Hexis/Assets.xcassets/exo-*.imageset")):
        asset = os.path.basename(path)[:-9]
        if asset not in wanted and asset not in allowed():
            out.append(f"unused image  {asset} (no exercise of Program.json)")
    return out


def _walk_exercises(node) -> list[dict]:
    found = []
    if isinstance(node, dict):
        if "name" in node and "sets" in node:
            found.append(node)
        for v in node.values():
            found += _walk_exercises(v)
    elif isinstance(node, list):
        for v in node:
            found += _walk_exercises(v)
    return found


def defaults_keys(sources: dict[str, str]) -> list[str]:
    text = "\n".join(strip_comments(t) for t in sources.values())
    out = []
    for name, literal in set(re.findall(r"(\w+)\s*=\s*\"([A-Za-z][\w.]*)\"", text)):
        if not name.lower().endswith("key"):
            continue
        uses = [m.start() for m in re.finditer(rf"\b{name}\b", text)]
        if len(uses) <= 1:
            out.append(f"unused key  {name} = \"{literal}\"")
    return out


def program_fields(sources: dict[str, str]) -> list[str]:
    importer = "".join(t for p, t in sources.items() if re.search(r"Program(Importer|Catalog|Sync)\.swift$", p))
    program = json.loads(read(os.path.join(ROOT, "Hexis/Resources/Program.json")))
    keys: set[str] = set()

    def walk(node):
        if isinstance(node, dict):
            keys.update(k for k in node if k != "volume")
            for k, v in node.items():
                if k != "volume":  # its keys are muscle names, not fields
                    walk(v)
        elif isinstance(node, list):
            for v in node:
                walk(v)

    walk(program)
    return [f"unread field  Program.json \"{k}\" is never read" for k in sorted(keys)
            if not re.search(rf"\b{re.escape(k)}\b|\"{re.escape(k)}\"", importer)]


def warnings(sources: dict[str, str]) -> list[str]:
    out = []
    allow = allowed()
    for path, text in sources.items():
        rel = os.path.relpath(path, ROOT)
        lines = text.count("\n")
        stem = os.path.basename(path)[:-6]
        if lines > BIG_FILE and "Schema/" not in rel and stem not in allow:
            out.append(f"big file  {rel} ({lines} lines)")
        for n, line in enumerate(text.splitlines(), 1):
            if re.search(r"//.*\b(TODO|FIXME)\b", line):
                out.append(f"todo  {rel}:{n}")
    return out


def scan() -> tuple[list[str], list[str]]:
    sources = {p: read(p) for p in swift_paths()}
    errors = unused_declarations(sources, allowed()) + exercise_images() + defaults_keys(sources)
    return sorted(errors), sorted(warnings(sources) + program_fields(sources))


if __name__ == "__main__":
    errs, warns = scan()
    print("\n".join(errs + warns) if errs or warns else "deadcode: clean")
    sys.exit(1 if errs else 0)
