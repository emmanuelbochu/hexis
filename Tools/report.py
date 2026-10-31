#!/usr/bin/env python3
"""Builds the daily report Tools/.data/report.md from the pieces the Mac can see; weekly_build.py calls build().

First line: `RAS` or `À CORRIGER (n)`. Then fixed sections: Données · Crashs et gels · Anomalies · Performance · Usage · Installation · Code ·
Chasse, and « Hexis Elle » when her iPhone was read (her data, crashes and anomalies; her problems count, prefixed « Elle : »). A new Claude conversation reads it first (CLAUDE.md) and fixes what it flags.
Usage: python3 Tools/report.py   (rebuilds from Tools/.data/latest.json and the local checks, for a quick look)
"""
from __future__ import annotations

import glob
import json
import os
import subprocess
import sys
import time
from collections import Counter
from datetime import datetime, timedelta, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "Tools", ".data")
BUNDLE = "com.example.Hexis"
# Anomalies that are bugs by themselves; the others (Gemini errors, slow launches) are only counted.
BLOCKING = {"saveFailed", "backupUnreadable", "programSyncFailed", "nonFiniteValue"}
RECENT_DAYS = 7


def run(cmd: list[str], cwd: str = ROOT, timeout: int = 300) -> str:
    try:
        out = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return out.stdout + out.stderr
    except (subprocess.TimeoutExpired, OSError):
        return ""


def fetch_diagnostics(device: str | None) -> None:
    """Copies the MetricKit reports of the iPhone (Documents/diagnostics) next to the other data; silent when unreachable."""
    if not device:
        return
    dest = os.path.join(DATA, "diagnostics")
    run(["rm", "-rf", dest])
    run(["xcrun", "devicectl", "device", "copy", "from", "--device", device, "--domain-type", "appDataContainer",
         "--domain-identifier", BUNDLE, "--source", "Documents/diagnostics", "--destination", dest], timeout=120)


def last_commit_time() -> float:
    out = run(["git", "log", "-1", "--format=%ct"]).strip()
    return float(out) if out.replace(".", "").isdigit() else 0.0


def crashes(app: str = "Hexis") -> tuple[list[str], list[str]]:
    """(problems, lines): the newest crash report of `app` (Hexis or HexisElle) if it is recent, plus his MetricKit counts."""
    problems, lines = [], []
    paths = sorted(glob.glob(os.path.expanduser(f"~/Library/Logs/CrashReporter/MobileDevice/*/{app}-*.ips"))
                   + glob.glob(os.path.expanduser(f"~/Library/Logs/DiagnosticReports/{app}-*.ips")), key=os.path.getmtime)
    if paths and time.time() - os.path.getmtime(paths[-1]) < RECENT_DAYS * 86400:
        # A commit made after the crash is taken to answer it: it is only shown, not flagged.
        handled = os.path.getmtime(paths[-1]) < last_commit_time()
        if not handled:
            problems.append("crash récent de l'iPhone : python3 Tools/crashlog.py")
        lines += ["Dernier crash (" + os.path.basename(paths[-1]) + (", avant le dernier commit" if handled else "") + ") :"]
        lines += run([sys.executable, os.path.join(ROOT, "Tools/crashlog.py"), paths[-1]]).splitlines()[:8]
    if app != "Hexis":
        return problems, lines or ["Aucun crash récent."]
    counts: Counter = Counter()
    for path in glob.glob(os.path.join(DATA, "diagnostics", "**", "*diagnostic.json"), recursive=True):
        try:
            payload = json.load(open(path, encoding="utf-8"))
        except (OSError, ValueError):
            continue
        for key in ("crashDiagnostics", "hangDiagnostics", "cpuExceptionDiagnostics", "diskWriteExceptionDiagnostics"):
            counts[key] += len(payload.get(key, []))
    for key, n in counts.items():
        if n and key in ("crashDiagnostics", "hangDiagnostics"):
            problems.append(f"MetricKit : {n} {key.replace('Diagnostics', '')}(s) : voir Tools/.data/diagnostics")
    lines.append("MetricKit : " + (", ".join(f"{k.replace('Diagnostics', '')} {n}" for k, n in counts.items()) or "rien reçu"))
    return problems, lines


def anomalies(doc: dict | None) -> tuple[list[str], list[str], int]:
    """(problems, lines, slow launches) from the in-app journal carried by the backup."""
    if doc is None:
        return [], ["Pas de sauvegarde lue."], 0
    entries = (doc.get("preferences") or {}).get("diagnostics") or []
    now = datetime.fromisoformat(doc["exportedAt"].replace("Z", "+00:00")) if "exportedAt" in doc else datetime.now(timezone.utc)
    recent = [e for e in entries if now - datetime.fromisoformat(e["date"].replace("Z", "+00:00")) < timedelta(days=RECENT_DAYS)]
    counts = Counter(e["kind"] for e in recent)
    problems = [f"anomalie « {k} » ×{n} sur {RECENT_DAYS} j (dernier détail : "
                f"{next(e['detail'] for e in reversed(recent) if e['kind'] == k)[:80]})" for k, n in counts.items() if k in BLOCKING]
    lines = [f"{k} ×{n}" for k, n in sorted(counts.items())] or [f"Aucune anomalie sur {RECENT_DAYS} jours."]
    return problems, lines, counts.get("slowLaunch", 0)


def install_section() -> tuple[list[str], list[str]]:
    """(problems, lines): age of the last automatic install (written by weekly_build.py); past 5 days it should have happened."""
    state = os.path.expanduser("~/Library/Application Support/HexisBuild")
    lines = []
    for label, name in (("Hexis", "last_success"), ("Hexis Elle (son iPhone)", "her_last_success")):
        try:
            age = (time.time() - float(open(os.path.join(state, name)).read())) / 86400
        except (OSError, ValueError):
            if name == "last_success":
                return ["aucune installation automatique enregistrée : zsh Tools/install_weekly_build.sh"], ["Jamais installée."]
            continue
        if name == "last_success" and age > 5:
            return [f"installation automatique vieille de {age:.1f} jours (expire à 7) : compil hexis, log ~/Library/Logs/HexisBuild.log"], [f"{label} : {age:.1f} jours."]
        lines.append(f"{label} : il y a {age:.1f} jours (renouvelée dès 3 jours).")
    return [], lines


def code_section(tree: str) -> tuple[list[str], list[str]]:
    out = run([sys.executable, os.path.join(tree, "Tools", "deadcode.py")], cwd=tree).splitlines()
    dead = [l for l in out if l.startswith(("dead code", "unused"))]
    other = [l for l in out if l not in dead and not l.startswith("deadcode:")]
    return [f"code mort : {l}" for l in dead], [f"{len(dead)} code mort, {len(other)} avertissements (python3 Tools/deadcode.py)"]


def data_problems(data_text: str, data_ok: bool) -> list[str]:
    problems = [l for l in data_text.splitlines() if "✘" in l or l.startswith("    ") or "introuvable" in l or "error:" in l][:20]
    return problems or ([] if data_ok else ["data_check.sh a échoué"])


def her_section(her: tuple[str, bool, str] | None) -> tuple[list[str], list[str]]:
    """(problems, lines) for her iPhone: `her` = (output of data_check.sh elle, success, path of her backup)."""
    if her is None:
        return [], []
    text, ok, latest = her
    if "introuvable" in text or "pas choisi" in text:
        return [], ["Son iPhone n'a pas répondu (hors du Wi-Fi du Mac) : rien de lu."]
    doc = json.load(open(latest, encoding="utf-8")) if os.path.exists(latest) else None
    problems = data_problems(text, ok)
    crash_problems, crash_lines = crashes("HexisElle")
    anomaly_problems, anomaly_lines, _ = anomalies(doc)
    summary = [l for l in text.splitlines() if "séances" in l or l.startswith("sauvegarde")][:2]
    found = problems + crash_problems + anomaly_problems
    return [f"Elle : {p}" for p in found], summary + (found or ["Saines."]) + crash_lines + anomaly_lines


def build(data_text: str, data_ok: bool, latest: str | None, tree: str, device: str | None = None,
          her: tuple[str, bool, str] | None = None) -> str:
    """`data_text`: output of data_check.sh; `latest`: path of the backup it fetched; `tree`: checkout of HEAD; `her`: hers, if read."""
    doc = json.load(open(latest, encoding="utf-8")) if latest and os.path.exists(latest) else None
    fetch_diagnostics(device)
    problems = data_problems(data_text, data_ok)
    crash_problems, crash_lines = crashes()
    anomaly_problems, anomaly_lines, slow = anomalies(doc)
    code_problems, code_lines = code_section(tree)
    install_problems, install_lines = install_section()
    usage = run([sys.executable, os.path.join(ROOT, "Tools", "usage.py"), latest]).splitlines() if doc else ["Pas de sauvegarde lue."]
    chasse_path = os.path.join(DATA, "chasse.md")
    chasse = open(chasse_path, encoding="utf-8").read().splitlines() if os.path.exists(chasse_path) else ["Aucune chasse automatique encore."]
    her_problems, her_lines = her_section(her)
    all_problems = problems + crash_problems + anomaly_problems + code_problems + install_problems + her_problems
    head = "RAS" if not all_problems else f"À CORRIGER ({len(all_problems)})"
    prefilled = [l for l in data_text.splitlines() if l.startswith("  ") and "kg" in l]
    sections = [
        ("Données", problems or ["Saines."]),
        ("Crashs et gels", crash_problems + crash_lines),
        ("Anomalies", anomaly_problems + anomaly_lines),
        ("Performance", [f"{slow} lancement(s) lent(s) (> 2 s) sur {RECENT_DAYS} j." if slow else "Pas de lancement lent.",
                         "Budgets de calcul : testés par check.sh (PerformanceTests)."]),
        ("Usage", usage),
        ("Installation", install_problems + install_lines),
        ("Code", code_problems + code_lines),
        ("Chasse", chasse),
    ] + ([("Hexis Elle", her_lines)] if her_lines else [])
    body = "\n\n".join(f"## {title}\n" + "\n".join(f"- {l}" if l and not l.startswith(("-", " ")) else l for l in lines) for title, lines in sections)
    todo = "\n".join(f"{i}. {p}" for i, p in enumerate(all_problems, 1))
    nxt = "\n\n## Prochaines séances préremplies\n" + "\n".join(prefilled)[:3000] if prefilled else ""
    return f"{head}\n\n# Rapport, {datetime.now():%Y-%m-%d %H:%M}\n\n" + (f"{todo}\n\n" if todo else "") + body + nxt + "\n"


if __name__ == "__main__":
    latest = os.path.join(DATA, "latest.json")
    hers = os.path.join(DATA, "her-latest.json")
    print(build("", True, latest if os.path.exists(latest) else None, ROOT, her=("", True, hers) if os.path.exists(hers) else None))
