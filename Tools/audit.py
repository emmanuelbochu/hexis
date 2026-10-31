"""Cheap static audit of the Swift code: run from the repo root, read only the output (a few lines).

Checks: force unwraps, print/try!, the banned word « dur » in any text the user can read (both apps, both programs), hard-coded colours/fonts outside Theme, NavigationStack in the pager pages (crash), .task on a Group that can be empty,
full-table fetches, long views, unreferenced types, models missing from the backup, dead code (deadcode.py), secrets in tracked files (secrets_scan.py).
"""
import glob, os, re, sys

files = [f for f in glob.glob("Hexis/**/*.swift", recursive=True)]
src = {f: open(f).read() for f in files}
issues = []


def code(f):
    """Source without #Preview blocks and comments."""
    text = re.sub(r"#Preview.*", "", src[f], flags=re.S)
    return re.sub(r"//.*", "", text)


PAGES = ("HomeView", "ProgramView", "HistoryView","NutritionTodayView", "NutritionPlanView", "ShoppingView")
for f in files:
    name = f.split("/")[-1][:-6]
    text = code(f)
    for n, line in enumerate(text.split("\n"), 1):
        if re.search(r"\b\w+!(?![=\w])\s*[.)\],]|\btry!|\bas!", line) and "Schema" not in f:
            issues.append(f"force unwrap/try!  {f}:{n}")
        if re.search(r"\bprint\(", line):
            issues.append(f"print           {f}:{n}")
        if "Theme/" not in f and re.search(r"Color\((red|white|black|hex|\.sRGB)|Color\.(red|green|blue|orange|yellow)\b|\.(red|blue|green|orange|yellow)\)", line):
            issues.append(f"hard-coded style {f}:{n}")
    if name in PAGES and "NavigationStack" in text:
        issues.append(f"NavigationStack in a pager page (crash) {f}")
    if name in PAGES and re.search(r"\.toolbar\s*\{", text):
        issues.append(f"toolbar in a pager page (use PageActionRow) {f}")
    if f.startswith("Hexis/Features") and re.search(r"(View|Sheet|Card)$", name) and len(src[f].split("\n")) > 200:
        issues.append(f"view > 200 lines ({len(src[f].splitlines())}) {f}")
    if re.search(r"FetchDescriptor<(SetLog|WorkoutSession)>\(\)", text) and "Backup" not in f:
        issues.append(f"full-table fetch {f}")

# Never the word « dur » on screen (CLAUDE.md): Swift string literals of both apps and the texts of both program files.
banned = re.compile(r"\b(?:très |assez |plus )?dur(?:e|s|es)?\b", re.I)
shown = files + glob.glob("HexisShared/**/*.swift", recursive=True) + glob.glob("HexisWidgets/**/*.swift", recursive=True)
for f in shown:
    for n, line in enumerate((code(f) if f in src else open(f).read()).split("\n"), 1):
        if any(banned.search(literal) for literal in re.findall(r'"([^"\\]*(?:\\.[^"\\]*)*)"', line)):
            issues.append(f"word « dur » shown  {f}:{n}")
for f in ("Hexis/Resources/Program.json", "HexisElle/Program.json"):
    for n, line in enumerate(open(f).read().split("\n"), 1):
        if banned.search(line):
            issues.append(f"word « dur » shown  {f}:{n}")

# Every exercise of each program has its picture (his: exo-<slug> drawn by exo_images.py; hers: elle-exo-<slug>, --elle).
def exercise_names(o, out):
    if isinstance(o, dict):
        if "name" in o and "muscleGroup" in o:
            out.add(o["name"])
        for v in o.values():
            exercise_names(v, out)
    elif isinstance(o, list):
        for v in o:
            exercise_names(v, out)
    return out


def slug(name):
    import unicodedata
    folded = unicodedata.normalize("NFD", name).encode("ascii", "ignore").decode().lower()
    return "exo-" + "-".join(w for w in re.split(r"[^a-z0-9]+", folded) if w)


import json
for program, assets, prefix in (("Hexis/Resources/Program.json", "Hexis/Assets.xcassets", ""), ("HexisElle/Program.json", "HexisElle/Assets.xcassets", "elle-")):
    for name in sorted(exercise_names(json.load(open(program)), set())):
        if not os.path.isdir(f"{assets}/{prefix}{slug(name)}.imageset"):
            issues.append(f"no picture for « {name} » ({program}) : python3 Tools/exo_images.py{' --elle' if prefix else ''}")

# Types never used outside their own file (nested/private excluded)
everything = "\n".join(src.values())
for f, s in src.items():
    for t in re.findall(r"^(?:final )?(?:struct|class|enum)\s+(\w+)", s, re.M):
        outside = len(re.findall(rf"\b{t}\b", everything)) - len(re.findall(rf"\b{t}\b", s))
        inside = len(re.findall(rf"\b{t}\b", s))
        if outside == 0 and inside <= 1 and t not in ("HexisApp",) and "Preview" not in t:
            issues.append(f"unreferenced type {t} ({f})")

# Every @Model must be in the backup
models = re.findall(r"@Model\s+final class (\w+)", everything)
backup = src.get("Hexis/Services/BackupService.swift", "")
for m in models:
    if m not in backup:
        issues.append(f"@Model {m} missing from BackupService")

# Every stored property of a @Model must appear in the backup (a forgotten field is lost on restore).
backup_all = backup + src.get("Hexis/Services/BackupDocument.swift", "")
for f in files:
    for m in re.finditer(r"@Model\s+final class (\w+)[^{]*\{(.*?)\n\}\n", code(f), re.S):
        for v in re.finditer(r"^ {4}(?:var|let) (\w+)\s*[:=][^{\n]*$", m.group(2), re.M):
            if not re.search(rf"\b{v.group(1)}\b", backup_all):
                issues.append(f"@Model {m.group(1)}.{v.group(1)} missing from the backup ({f})")

# A .task/.onAppear on a Group that can be empty never runs (Group passes modifiers to its children): use a VStack.
for f in files:
    text = code(f)
    for m in re.finditer(r"\bGroup \{", text):
        depth, i = 0, m.end() - 1
        while i < len(text):
            depth += {"{": 1, "}": -1}.get(text[i], 0)
            if depth == 0:
                break
            i += 1
        block, after = text[m.end():i], text[i + 1:i + 200]
        if re.match(r"\s*if\b", block) and not re.search(r"else\s*\{", block) and re.match(r"(\s*\.[^\n]*\n)*?\s*\.(task|onAppear)\b", after):
            issues.append(f"task on a Group that can be empty (never runs) {f}:{text[:m.start()].count(chr(10)) + 1}")

# Dead code blocks the commit; big files and unread Program.json fields only warn (details: python3 Tools/deadcode.py)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import deadcode
import secrets_scan
dead, warned = deadcode.scan()
issues += dead + secrets_scan.scan_repository()
for w in warned:
    print("warning: " + w)

print("\n".join(sorted(set(issues))) if issues else "audit: clean")
sys.exit(1 if issues else 0)
