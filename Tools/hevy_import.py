#!/usr/bin/env python3
"""Turns her Hevy export (workout_data.csv) into HexisElle/HevyHistory.json, the history Hexis Elle loads by itself at launch (HistorySeed).

Usage: python3 Tools/hevy_import.py [path/to/workout_data.csv]      (default: ~/Downloads/workout_data.csv)

Every Hevy lift is one of two kinds:
  SAME  the very lift (same machine, same movement; « Relevé de bassin (barre) » is Hevy's label, she only ever used the machine) of her program: its sets are stored under the program's exercise name, in the unit
        the app asks for (LoadProfile.guess), so the next goal, the warmups and the machine's weights start from what she really lifts.
  OWN   anything else (other movement, other equipment: cable row ≠ the plate-loaded
        Matrix row): kept in her history under its own name, weights as typed in Hevy, never used to calibrate another lift.
Lifts without a single rep (plank, walking lunges with no reps) are dropped. Hevy has no time per set: every set gets the session's
start, so the app reads these sessions as « not a real timeline » (`SessionTimeline`) and never learns rests or order from them.

What a number means in Hevy (checked against the data, see docs/20-regles.md):
  stack machines (pulldown 32/39, leg curl 27/32, abduction 39/45/50/54: steps of 5-7 kg)  → the stack's weight, as in the app;
  dumbbells (8, 10, 12, 15, 16, 17.5)                                                       → one dumbbell, as in the app;
  Smith squat 30 and leg press 100                                                                        → the plates in total, so ÷ 2 for the
  app, which asks for one side (a stack never stays at 100 for six months; 100 per side would be 200+ kg for a 60 kg beginner).
"""
import csv
import json
import sys
import uuid
from collections import OrderedDict
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "HexisElle" / "HevyHistory.json"
PROGRAM = ROOT / "HexisElle" / "Program.json"
PARIS = ZoneInfo("Europe/Paris")
NAMESPACE = uuid.UUID("6f1b6c9e-4a0e-4f64-9a53-0d6f4c5b7e11")
VERSION = 2

MONTHS = {"janv.": 1, "févr.": 2, "mars": 3, "avr.": 4, "mai": 5, "juin": 6, "juil.": 7, "août": 8, "sept.": 9, "oct.": 10, "nov.": 11, "déc.": 12}

# Hevy title → the session of her program it stands for (Hevy's third session was an older program: none).
TEMPLATES = {"Séance 1": "Séance A", "Séance 2": "Séance B"}

# Hevy name → (name in her program, factor Hevy → app).
SAME = {
    "Relevé de Bassin (Barre)": ("Hip thrust machine", 1),
    "Squat (Machine Smith)": ("Squat Smith", 0.5),
    "Tirage Poitrine (Machine)": ("Tirage vertical", 1),
    "Abduction Hanche (Machine)": ("Abduction machine", 1),
    "Abduction Hanche": ("Abduction machine", 1),
    "Soulevé de Terre Roumain (Haltère)": ("RDL", 1),
    "Presse à Cuisses": ("Presse à cuisses", 0.5),
    "Leg Curl Assis (Machine)": ("Leg curl assis", 1),
    "Leg Curl Assis": ("Leg curl assis", 1),
    "Élévation Latérale (Haltère)": ("Élévations latérales haltères", 1),
}

# Hevy name → (name kept, muscle, how the number reads: perHand / stack / total).
OWN = {
    "Squat (Haltère)": ("Squat gobelet haltère", "Quadriceps", "total"),
    "Développé Militaire (Haltère)": ("Développé militaire haltères", "Deltoïdes antérieurs", "perHand"),
    "Développé Couché (Haltère)": ("Développé couché haltères", "Pectoraux", "perHand"),
    "Pompes": ("Pompes", "Pectoraux", "total"),
    "Pompes Inclinées": ("Pompes inclinées", "Pectoraux", "total"),
    "Fentes (Barre)": ("Fentes barre", "Quadriceps", "total"),
    "Extension Dos (Hyperextension)": ("Extension dos", "Dos", "total"),
    "Rowing Poulie Assis - Prise en V": ("Rowing poulie assis, prise en V", "Dos", "stack"),
    "Tirage assis à la poulie - prise en V (poulie)": ("Rowing poulie assis, prise en V", "Dos", "stack"),
    "Extension Triceps Poulie Haute": ("Triceps poulie haute", "Triceps", "stack"),
    "Kickbacks Poulie": ("Kickback fessier poulie", "Fessiers", "stack"),
}


def parse_date(text):
    day, month, year, clock = text.replace(",", "").split()
    hour, minute = clock.split(":")
    return datetime(int(year), MONTHS[month], int(day), int(hour), int(minute), tzinfo=PARIS)


def number(text):
    return float(text) if text.strip() else None


def build(csv_path):
    program_names = {e["name"] for w in json.load(open(PROGRAM))["workouts"] for b in w["blocks"] for e in b["exercises"]}
    for name, _ in SAME.values():
        assert name in program_names, f"{name} is not in her Program.json"

    sessions = OrderedDict()
    for row in csv.DictReader(open(csv_path, encoding="utf-8")):
        sessions.setdefault((row["title"], row["start_time"], row["end_time"]), []).append(row)

    exercises, out = OrderedDict(), []
    for (title, start_text, end_text), rows in sessions.items():
        start, end = parse_date(start_text), parse_date(end_text)
        sets = []
        for row in rows:
            if row["set_type"] != "normal" or not row["reps"].strip():
                continue
            hevy = row["exercise_title"]
            weight = number(row["weight_kg"]) or 0
            if hevy in SAME:
                name, factor = SAME[hevy]
                exercises.setdefault(name, {"name": name, "load": None})
                sets.append((name, round(weight * factor, 2), int(row["reps"])))
            elif hevy in OWN:
                name, muscle, load = OWN[hevy]
                exercises.setdefault(name, {"name": name, "muscle": muscle, "load": load})
                sets.append((name, weight, int(row["reps"])))
            else:
                print(f"  ignored (no mapping): {hevy}")
        if not sets:
            continue
        out.append({
            "id": str(uuid.uuid5(NAMESPACE, f"{title}|{start_text}")).upper(),
            "start": start.astimezone(ZoneInfo("UTC")).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "end": end.astimezone(ZoneInfo("UTC")).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "template": TEMPLATES.get(title),
            "sets": [{"exercise": n, "weight": w, "reps": r} for n, w, r in sets],
        })
    out.sort(key=lambda s: s["start"])
    return {"version": VERSION, "exercises": list(exercises.values()), "sessions": out}


if __name__ == "__main__":
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / "Downloads" / "workout_data.csv"
    data = build(path)
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    total = sum(len(s["sets"]) for s in data["sessions"])
    print(f"{OUT.relative_to(ROOT)}: {len(data['sessions'])} sessions, {total} sets, {len(data['exercises'])} exercises")
