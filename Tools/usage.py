#!/usr/bin/env python3
"""What the user really uses, measured on the last backup of the iPhone (Tools/.data/latest.json, see data_check.sh).

Two sources: the traces the app already leaves in its data (sessions, feelings, meals, tickets, corrections…) and the
screen counters of UsageCounter (saved in the backup preferences). Never decides anything: a feature at 0 for a long time
goes to ROADMAP "Idées à évaluer", the user decides.
Usage: python3 Tools/usage.py [backup.json]      Output: a short report, also the "Usage" section of report.md
"""
from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timedelta, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT = os.path.join(ROOT, "Tools", ".data", "latest.json")
WINDOWS = (30, 90)
SCREENS = {
    "analyse": "Analyse", "time": "Temps", "weekReview": "Bilan de la semaine", "exerciseProgress": "Progrès d'un exo",
    "exerciseSheet": "Fiche d'exo (Programme)", "pantry": "Placard", "nutritionPlan": "Plan alimentaire", "gyms": "Salles",
    "adjustments": "Carte « Ajusté pour toi » dépliée", "exerciseDetails": "Carte d'exo dépliée (« i »)",
}


def parse(s: str) -> datetime:
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


def count_since(items: list[dict], field: str, since: datetime, keep=lambda x: True) -> int:
    return sum(1 for x in items if keep(x) and field in x and parse(x[field]) >= since)


def traces(doc: dict, now: datetime) -> list[tuple[str, list[int]]]:
    sessions = doc.get("sessions", [])
    session_ids = {s["id"] for s in sessions}
    feelings = doc.get("feelings", [])
    rows = [
        ("Séances terminées", lambda d: count_since(sessions, "date", d, lambda s: s.get("state") == "finished")),
        ("« Fatigué » (par séance)", lambda d: count_since(feelings, "createdAt", d,
                                                          lambda f: f["feeling"] == "tired" and f["exerciseID"] in session_ids)),
        ("« Gêne » (par exo)", lambda d: count_since(feelings, "createdAt", d, lambda f: f["feeling"] == "pain")),
        ("Rappels de séance (CarryNote)", lambda d: count_since(doc.get("carryNotes", []), "createdAt", d)),
        ("Notes de séance", lambda d: count_since(doc.get("sessionNotes", []), "createdAt", d)),
        ("Repas « Mangé »", lambda d: count_since(doc.get("planLogs", []), "day", d)),
        ("Aliments saisis (hors plan)", lambda d: count_since(doc.get("foodEntries", []), "date", d,
                                                              lambda e: not e["name"].startswith("Plan"))),
        ("Achats lus sur ticket (lignes du plan)", lambda d: count_since(doc.get("purchases", []), "date", d)),
        ("Lignes hors plan de ticket", lambda d: count_since(doc.get("extras", []), "date", d)),
        ("Corrections de ticket (ReceiptAlias)", lambda d: count_since(doc.get("aliases", []), "createdAt", d)),
        ("Déloads planifiés", lambda d: count_since(doc.get("deloadWeeks", []), "start", d)),
        ("Changements durables (ExerciseTweak)", lambda d: count_since(doc.get("tweaks", []), "since", d)),
        ("Cases de courses cochées (cycles)", lambda d: count_since(doc.get("shoppingChecks", []), "cycleStart", d)),
    ]
    return [(label, [fn(now - timedelta(days=w)) for w in WINDOWS]) for label, fn in rows]


def screens(doc: dict, now: datetime) -> list[str]:
    usage = (doc.get("preferences") or {}).get("usage")
    if usage is None:
        return ["Compteurs d'écrans : pas encore là (installer la version qui les contient, puis laisser passer des semaines)."]
    lines = []
    for key, label in SCREENS.items():
        entry = usage.get(key)
        if not entry:
            lines.append(f"- {label} : jamais ouvert depuis le début du comptage")
            continue
        last = parse(entry["last"])
        age = (now - last).days
        flag = "  ← à retirer ?" if age >= 30 else ("  ← à rendre automatique ?" if entry["count"] <= 2 else "")
        lines.append(f"- {label} : {entry['count']} ouverture(s), dernière il y a {age} j{flag}")
    return lines


def report(doc: dict) -> list[str]:
    now = parse(doc["exportedAt"]) if "exportedAt" in doc else datetime.now(timezone.utc)
    lines = [f"Sauvegarde du {now:%Y-%m-%d}. Colonnes : {WINDOWS[0]} j · {WINDOWS[1]} j"]
    lines += [f"- {label} : {a} · {b}" for label, (a, b) in traces(doc, now)]
    lines += ["", "Écrans :"] + screens(doc, now)
    return lines


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT
    if not os.path.exists(path):
        sys.exit("usage: no backup found (run zsh Tools/data_check.sh first)")
    with open(path, encoding="utf-8") as f:
        print("\n".join(report(json.load(f))))
