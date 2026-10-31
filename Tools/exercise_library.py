#!/usr/bin/env python3
"""Both programs' exercises in one file (Hexis/Resources/ExerciseLibrary.json), bundled in both apps:
« Remplacer l'exercice » offers every exercise of the two of them. `--check` fails if the file is stale."""
import json, sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
out = root / "Hexis/Resources/ExerciseLibrary.json"


def exercises(node, found):
    if isinstance(node, dict):
        if isinstance(node.get("name"), str) and isinstance(node.get("muscleGroup"), str) and "sets" in node:
            found.setdefault(node["name"], {"name": node["name"], "muscleGroup": node["muscleGroup"], "unilateral": bool(node.get("unilateral", False))})
        for value in node.values():
            exercises(value, found)
    elif isinstance(node, list):
        for value in node:
            exercises(value, found)


found = {}
for program in ("Hexis/Resources/Program.json", "HexisElle/Program.json"):
    exercises(json.loads((root / program).read_text()), found)
text = json.dumps(sorted(found.values(), key=lambda e: e["name"]), ensure_ascii=False, indent=1) + "\n"
if "--check" in sys.argv:
    if not out.exists() or out.read_text() != text:
        print("ExerciseLibrary.json is stale: python3 Tools/exercise_library.py")
        sys.exit(1)
else:
    out.write_text(text)
    print(f"{len(found)} exercises")
