#!/usr/bin/env python3
"""Keeps Hexis (and Hexis Elle, for tests) installed on his iPhone, and Hexis Elle on hers, before the free profile (7 days)
expires, without anyone doing anything.

launchd runs it every 10 minutes (see Tools/install_weekly_build.sh); each run is a cheap check. It builds the last
commit (git archive of HEAD, never the half-edited working tree) and installs it over Wi-Fi at a good moment:
- from EARLY_DAYS after the last install: when the iPhone answers AND is locked (not in use), the Mac has been idle
  for a few minutes and has power, and the hour is one where the two are usually together (learned in habits.json);
- a NEW COMMIT (HEAD differs from the one last installed) is installed the same way, so his fixes arrive the same day without
  anyone typing `compil`: only once HEAD has been still for FRESH_SETTLE_MINUTES (a burst of commits builds once), at most once
  every FRESH_HOURS, never on a retry window, and never at an unsafe moment (the same locked / idle / powered / usual-hour test);
- from URGENT_DAYS: at the first moment the iPhone answers, whatever its state;
- a failure is retried after RETRY_MINUTES; the only Mac notification is the critical one (CRITICAL_DAYS, every 12 h).
The app itself warns on the iPhone before its profile expires (ProfileExpiry).
Her iPhone (Tools/.data/her-device, see Tools/her_phone.sh pair) has its own clock (her_* state files) and is only reachable at
the weekend: installed when it answers, locked or not during her visit (Friday evening to Sunday afternoon, she does not train then: on arrival
from EARLY_DAYS, again before she leaves from half a day), locked only out of the visit, at any moment from URGENT_DAYS; a weekday `compil hexis2` asks for a check at the next weekend (see her_due); her backup is checked like his (report section « Hexis Elle »).
Usage: weekly_build.py [--force]   Log: ~/Library/Logs/HexisBuild.log
"""
from __future__ import annotations

import fcntl
import json
import plistlib
import re
import shutil
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
HOME = Path.home()
STATE = HOME / "Library/Application Support/HexisBuild"
LOG = HOME / "Library/Logs/HexisBuild.log"
SRC = HOME / "Library/Caches/HexisBuild/src"
DERIVED = HOME / "Library/Caches/HexisBuild/DerivedData"
CHECK = HOME / "Library/Caches/HexisBuild/check"
REPORT = PROJECT / "Tools/.data/report.md"
REPORT_HOURS = 20
EARLY_DAYS = 3.0
URGENT_DAYS = 5.0
CRITICAL_DAYS = 5.5
RETRY_MINUTES = 30
FRESH_HOURS = 6.0  # at most one install for new commits in this many hours
FRESH_SETTLE_MINUTES = 20  # HEAD must not have moved for this long
CHASSE_DAYS = 3.0  # at most one automatic bug hunt in this many days
IDLE_SECONDS = 120
MIN_SAMPLES = 30  # reachable observations before the habit is trusted
DECAY = 0.999  # old habits fade slowly


def log(message: str) -> None:
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a") as f:
        f.write(f"{datetime.now():%Y-%m-%d %H:%M:%S} {message}\n")


def notify(title: str, text: str) -> None:
    subprocess.run(["/usr/bin/osascript", "-e", f'display notification "{text}" with title "{title}"'], check=False)


def run(cmd: list[str], timeout: int = 60) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return subprocess.CompletedProcess(cmd, 124, "", "timeout")


def read_float(name: str) -> float:
    try:
        return float((STATE / name).read_text())
    except (OSError, ValueError):
        return 0.0


def write_float(name: str, value: float) -> None:
    (STATE / name).write_text(str(value))


# MARK: - Device

HER_DEVICE = PROJECT / "Tools/.data/her-device"
MY_DEVICE = PROJECT / "Tools/.data/my-device"


def her_device() -> str | None:
    try:
        return HER_DEVICE.read_text().strip() or None
    except OSError:
        return None


def device_id() -> str | None:
    """His iPhone: the one pinned in Tools/.data/my-device, else the first paired one (cable or Wi-Fi) that is not hers, then pinned.
    Pinned, it can never turn out to be hers (his app must never land on her iPhone)."""
    try:
        pinned = MY_DEVICE.read_text().strip()
    except OSError:
        pinned = ""
    if pinned and pinned.upper() != (her_device() or "").upper():
        return pinned
    out = STATE / "devices.json"
    if run(["/usr/bin/xcrun", "devicectl", "list", "devices", "--json-output", str(out)]).returncode != 0:
        return None
    try:
        devices = json.loads(out.read_text())["result"]["devices"]
    except (OSError, ValueError, KeyError):
        return None
    hers = (her_device() or "").upper()
    for d in devices:
        hardware = d.get("hardwareProperties", {})
        if hardware.get("platform") == "iOS" and (not hers or hers not in (hardware.get("udid", "").upper(), d.get("identifier", "").upper())):
            MY_DEVICE.parent.mkdir(parents=True, exist_ok=True)
            MY_DEVICE.write_text(hardware["udid"])
            return hardware["udid"]
    return None


def head_commit() -> tuple[str, float] | None:
    """HEAD's hash and commit time (the build is always HEAD, never the working tree)."""
    out = run(["/usr/bin/git", "-C", str(PROJECT), "log", "-1", "--format=%H %ct"], 10).stdout.split()
    return (out[0], float(out[1])) if len(out) == 2 else None


def read_text(name: str) -> str:
    try:
        return (STATE / name).read_text().strip()
    except OSError:
        return ""


def probe(device: str) -> bool | None:
    """None: the iPhone does not answer. True: it answers and is locked (not in use). False: it answers and is in use."""
    out = STATE / "lock.json"
    if run(["/usr/bin/xcrun", "devicectl", "device", "info", "lockState", "--device", device, "--json-output", str(out)], 25).returncode != 0:
        return None
    try:
        return bool(json.loads(out.read_text())["result"]["passcodeRequired"])
    except (OSError, ValueError, KeyError):
        return None


# MARK: - Mac state and habits

def mac_idle_seconds() -> float:
    out = run(["/usr/sbin/ioreg", "-c", "IOHIDSystem"], 10).stdout
    match = re.search(r'"HIDIdleTime" = (\d+)', out)
    return int(match.group(1)) / 1e9 if match else 0.0


def mac_has_power() -> bool:
    out = run(["/usr/bin/pmset", "-g", "batt"], 10).stdout
    if "AC Power" in out:
        return True
    match = re.search(r"(\d+)%", out)
    return bool(match) and int(match.group(1)) >= 40


def learn(reachable: bool) -> list[float]:
    """Counts, per hour of the day, the runs where the Mac was awake and the iPhone answered."""
    path = STATE / "habits.json"
    try:
        habits = [float(x) for x in json.loads(path.read_text())]
        habits = habits if len(habits) == 24 else [0.0] * 24
    except (OSError, ValueError):
        habits = [0.0] * 24
    if reachable:
        habits = [h * DECAY for h in habits]
        habits[datetime.now().hour] += 1
        path.write_text(json.dumps(habits))
    return habits


def usual_hour(habits: list[float], hour: int) -> bool:
    """True when this hour is one of those where the iPhone is usually reachable (always true while still learning)."""
    if sum(habits) < MIN_SAMPLES:
        return True
    return habits[hour] >= 0.5 * max(habits)


# MARK: - Build

def prepare_source() -> bool:
    shutil.rmtree(SRC, ignore_errors=True)
    SRC.mkdir(parents=True)
    archive = subprocess.run(
        f"git -C '{PROJECT}' archive HEAD | tar -x -C '{SRC}'", shell=True, capture_output=True, text=True
    )
    if archive.returncode != 0:
        log(f"git archive failed: {archive.stderr.strip()}")
        return False
    secrets = PROJECT / "Hexis/Secrets.plist"  # ignored by Git, needed to run
    if secrets.exists():
        shutil.copy(secrets, SRC / "Hexis/Secrets.plist")
    return True


def build(scheme: str = "Hexis") -> Path | None:
    result = run(
        ["/usr/bin/xcodebuild", "-project", str(SRC / "Hexis.xcodeproj"), "-scheme", scheme,
         "-configuration", "Release", "-destination", "generic/platform=iOS",
         "-derivedDataPath", str(DERIVED), "-allowProvisioningUpdates", "build"],
        3600,
    )
    if result.returncode != 0:
        errors = [l for l in (result.stdout + result.stderr).splitlines() if "error:" in l or "BUILD FAILED" in l]
        log("build failed:\n  " + "\n  ".join(errors[:8]))
        return None
    app = DERIVED / f"Build/Products/Release-iphoneos/{scheme}.app"
    return app if app.exists() else None


ELLE_BUNDLE = "com.example.Hexis.Elle"


def bundle_of(app: Path) -> str:
    try:
        return plistlib.loads((app / "Info.plist").read_bytes()).get("CFBundleIdentifier", "")
    except (OSError, ValueError):
        return ""


def install(app: Path, device: str, hers: bool = False) -> bool:
    """`hers`: her iPhone, which only ever receives Hexis Elle (checked on the built app itself, not on the scheme's name)."""
    if hers and bundle_of(app) != ELLE_BUNDLE:
        log(f"refused: {bundle_of(app) or app.name} is not Hexis Elle, never installed on her iPhone")
        return False
    result = run(["/usr/bin/xcrun", "devicectl", "device", "install", "app", "--device", device, str(app)], 900)
    if result.returncode != 0:
        lines = (result.stderr or result.stdout).strip().splitlines()
        log("install failed: " + (lines[-1] if lines else "no output"))
        return False
    return True


def data_report(device: str | None = None) -> None:
    """Checks the real history of the iPhone with the life-simulator checks of HEAD and writes Tools/.data/report.md
    (sections built by report.py). A new Claude conversation reads it first (CLAUDE.md) and fixes what it flags."""
    shutil.rmtree(CHECK, ignore_errors=True)
    CHECK.mkdir(parents=True)
    archive = subprocess.run(f"git -C '{PROJECT}' archive HEAD | tar -x -C '{CHECK}'", shell=True, capture_output=True, text=True)
    if archive.returncode != 0:
        return
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    (CHECK / "Tools/.data").mkdir(parents=True, exist_ok=True)
    if HER_DEVICE.exists():
        shutil.copy(HER_DEVICE, CHECK / "Tools/.data/her-device")
    checked = {}
    for who, backup in (("", "latest.json"), ("elle", "her-latest.json")):
        if who and not her_device():
            continue
        result = run(["/bin/zsh", str(CHECK / "Tools/data_check.sh")] + ([who] if who else []), 1500)
        fetched = CHECK / "Tools/.data" / backup
        if fetched.exists():
            shutil.copy(fetched, REPORT.parent / backup)  # usage.py and the next conversation read it from the project
        checked[who] = (re.sub(r"\x1b\[[0-9;]*m", "", result.stdout + result.stderr), result.returncode == 0)
    sys.path.insert(0, str(PROJECT / "Tools"))
    import report
    text, ok = checked[""]
    her = checked.get("elle")
    REPORT.write_text(report.build(text, ok, str(REPORT.parent / "latest.json"), str(CHECK), device,
                                   her=(her[0], her[1], str(REPORT.parent / "her-latest.json")) if her else None))
    write_float("last_report", time.time())
    log("data report: " + REPORT.read_text().splitlines()[0])


def chasse_due(report_head: str) -> str | None:
    """Why an automatic bug hunt (auto_chasse.sh) should start now, or None. Costs money, so it is rare: the report says
    À CORRIGER, or 4+ new real sessions, or 10+ commits since the last hunt; at most every 3 days; Mac idle and powered;
    never while a session may be running (last set under 3 hours ago)."""
    if time.time() - read_float("last_chasse") < CHASSE_DAYS * 86400 or mac_idle_seconds() < IDLE_SECONDS or not mac_has_power():
        return None
    latest = REPORT.parent / "latest.json"
    try:
        doc = json.loads(latest.read_text())
        last_set = max((datetime.fromisoformat(x["completedAt"].replace("Z", "+00:00")) for x in doc["sets"]), default=None)
        sessions = sum(1 for x in doc["sessions"] if x.get("state") == "finished")
    except (OSError, ValueError, KeyError):
        return None
    if last_set and (datetime.now(last_set.tzinfo) - last_set).total_seconds() < 3 * 3600:
        return None
    try:
        known = json.loads((STATE / "chasse.json").read_text())
    except (OSError, ValueError):
        known = {"sessions": sessions, "commit": "HEAD~1"}
    commits = run(["git", "-C", str(PROJECT), "rev-list", "--count", f"{known['commit']}..HEAD"], 20).stdout.strip()
    if report_head.startswith("À CORRIGER"):
        return "report says À CORRIGER"
    if sessions - known["sessions"] >= 4:
        return f"{sessions - known['sessions']} new sessions"
    if commits.isdigit() and int(commits) >= 10:
        return f"{commits} commits"
    return None


def start_chasse(reason: str) -> None:
    log(f"automatic hunt: {reason}")
    write_float("last_chasse", time.time())
    sessions = 0
    try:
        sessions = sum(1 for x in json.loads((REPORT.parent / "latest.json").read_text())["sessions"] if x.get("state") == "finished")
    except (OSError, ValueError, KeyError):
        pass
    head = run(["git", "-C", str(PROJECT), "rev-parse", "HEAD"], 20).stdout.strip()
    (STATE / "chasse.json").write_text(json.dumps({"sessions": sessions, "commit": head}))
    subprocess.Popen(["/bin/zsh", str(PROJECT / "Tools/auto_chasse.sh")], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)


def at_hers(moment: datetime) -> bool:
    """She is at his place from Friday evening to Sunday afternoon, her iPhone on the Mac's Wi-Fi, and does not train then."""
    day = moment.weekday()
    return (day == 4 and moment.hour >= 18) or day == 5 or (day == 6 and moment.hour < 18)


def her_due(age: float, moment: datetime, force: bool) -> bool:
    """The free profile lasts 7 days and her iPhone is reachable only while she is here: refreshed on arrival (from 3 days) and
    again before she leaves (from half a day) so she goes home with a full week. A `compil hexis2` run in the week leaves a flag
    (her_check): her visit installs it again whatever its age, to be sure it really works on her phone."""
    if force or age >= URGENT_DAYS or (at_hers(moment) and (STATE / "her_check").exists()):
        return True
    if at_hers(moment) and moment.weekday() == 6:
        return age >= 0.5
    return age >= EARLY_DAYS


def build_cached(scheme: str, key: str) -> Path | None:
    """The app of HEAD for `scheme`: reused when HEAD has not moved since its last good build (a second weekend install is free)."""
    head = run(["git", "-C", str(PROJECT), "rev-parse", "HEAD"], 20).stdout.strip()
    app = DERIVED / f"Build/Products/Release-iphoneos/{scheme}.app"
    marker = STATE / f"{key}_built"
    try:
        if head and app.exists() and marker.read_text() == head:
            return app
    except OSError:
        pass
    built = build(scheme) if prepare_source() else None
    if built is not None and head:
        marker.write_text(head)
    return built


def her_cycle(now: float, force: bool) -> None:
    """Her iPhone: Hexis Elle alone, on its own clock; never touches his install or his alerts."""
    device = her_device()
    age = (now - read_float("her_last_success")) / 86400
    moment = datetime.now()
    if not device or not her_due(age, moment, force) or (not force and now - read_float("her_last_attempt") < RETRY_MINUTES * 60):
        return
    state = probe(device)
    if state is None:
        if at_hers(moment) and age >= 4 and now - read_float("her_last_alert") > 12 * 3600:
            write_float("her_last_alert", now)
            notify("Hexis Elle expire bientôt", "Son iPhone est introuvable : allumé, sur le Wi-Fi du Mac, Mac allumé.")
        return
    if not force and age < URGENT_DAYS and not state and not at_hers(moment):
        return  # in her hands, away from the visit: wait for a better moment (she does not train at his place)
    log(f"her iPhone: building Hexis Elle (last good install {age:.1f} days ago)")
    write_float("her_last_attempt", now)
    app = build_cached("HexisElle", "her")
    if app is not None and install(app, device, hers=True):
        write_float("her_last_success", time.time())
        (STATE / "her_check").unlink(missing_ok=True)
        log("her iPhone: Hexis Elle installed, valid 7 more days")


def main() -> int:
    STATE.mkdir(parents=True, exist_ok=True)
    lock = open(STATE / "lock", "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return 0  # another run is going

    now = time.time()
    force = "--force" in sys.argv
    age = (now - read_float("last_success")) / 86400

    device = device_id()
    state = probe(device) if device else None  # also feeds the habit, so it runs on every check
    habits = learn(state is not None)
    if state is not None and now - read_float("last_report") > REPORT_HOURS * 3600 and mac_idle_seconds() >= IDLE_SECONDS:
        data_report(device)
        reason = chasse_due(REPORT.read_text().splitlines()[0]) if REPORT.exists() else None
        if reason:
            start_chasse(reason)
    her_cycle(now, force)
    head = head_commit()
    # New commits since the last install: wanted the same day, once HEAD has settled and not too often.
    fresh = bool(head) and head[0] != read_text("last_head") and now - head[1] >= FRESH_SETTLE_MINUTES * 60 \
        and now - read_float("last_success") >= FRESH_HOURS * 3600
    if not force and age < EARLY_DAYS and not fresh:
        return 0

    if state is None:
        if age >= CRITICAL_DAYS and now - read_float("last_alert") > 12 * 3600:
            write_float("last_alert", now)
            notify("Hexis expire bientôt", "iPhone introuvable : allume-le sur le même Wi-Fi que le Mac, Mac allumé.")
        return 1
    if not force and now - read_float("last_attempt") < RETRY_MINUTES * 60:
        return 1
    if not force and age < URGENT_DAYS:
        good = state and mac_idle_seconds() >= IDLE_SECONDS and mac_has_power() and usual_hour(habits, datetime.now().hour)
        if not good:
            return 0  # wait for a better moment

    log(f"building (last good install {age:.1f} days ago)")
    write_float("last_attempt", now)
    ok = prepare_source()
    app = build() if ok else None
    if app is not None and install(app, device):
        write_float("last_success", time.time())
        if head:
            (STATE / "last_head").write_text(head[0])
        log("installed, valid 7 more days" + (" (new commits)" if fresh else ""))
        # Hexis Elle rides along on the same iPhone (her own phone has `Tools/her_phone.sh`); its failure never blocks his app.
        elle = build("HexisElle") if ok else None
        log("Hexis Elle installed too" if elle is not None and install(elle, device) else "Hexis Elle not installed (see above)")
        return 0
    if age >= CRITICAL_DAYS and now - read_float("last_alert") > 12 * 3600:
        write_float("last_alert", now)
        notify("Hexis : mise à jour impossible", "Il faut la faire avant l'expiration. Détail : ~/Library/Logs/HexisBuild.log")
    return 1


if __name__ == "__main__":
    sys.exit(main())
