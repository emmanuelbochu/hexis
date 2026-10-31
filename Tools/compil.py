#!/usr/bin/env python3
"""On-demand install of the apps from the working tree (Release), one line per step.
  compil hexis    Hexis + Hexis Elle on HIS iPhone
  compil hexis2   the same, plus Hexis Elle (only, checked on the built app) on HER iPhone
  compil status   what is installed where, days left, who answers
It takes the same lock as the automatic job (weekly_build.py): the two never build or install at the same time."""
from __future__ import annotations

import fcntl
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import weekly_build as wb

DERIVED = Path.home() / "Library/Developer/Xcode/DerivedData"
APPS = {"Hexis": "Hexis-device", "HexisElle": "HexisElle-device"}

# What the Mac says when it cannot, in words: (text to find, what to do)
HINTS = [
    ("locked", "Déverrouille l'iPhone, puis relance."),
    ("developer mode", "Active le mode développeur : Réglages ▸ Confidentialité et sécurité ▸ Mode développeur."),
    ("trust", "Réglages ▸ Général ▸ VPN et gestion de l'appareil ▸ Faire confiance."),
    ("no account", "Xcode ▸ Réglages ▸ Comptes : reconnecte ton compte Apple."),
    ("session has expired", "Xcode ▸ Réglages ▸ Comptes : reconnecte ton compte Apple."),
    ("provisioning", "Xcode ▸ Réglages ▸ Comptes : vérifie ton compte Apple (profil expiré ou limite de 10 apps par semaine atteinte)."),
    ("signing", "Xcode ▸ Réglages ▸ Comptes : vérifie ton compte Apple."),
    ("space", "Plus de place sur l'iPhone."),
    ("timed out", "iPhone injoignable : branche-le en USB, ou même Wi-Fi que le Mac."),
    ("connect", "iPhone injoignable : branche-le en USB, ou même Wi-Fi que le Mac."),
]


def hint(text: str) -> str:
    low = text.lower()
    return next((advice for key, advice in HINTS if key in low), "Détail : ~/Library/Logs/HexisBuild.log")


def duration(seconds: float) -> str:
    return f"{int(seconds)} s" if seconds < 60 else f"{int(seconds // 60)} min {int(seconds % 60):02d}"


def ok(text: str) -> None: print(f"✔ {text}")
def bad(text: str, advice: str = "") -> None: print(f"✘ {text}" + (f"\n    → {advice}" if advice else ""))


def take_lock():
    """The job's own lock: waits for it (an automatic build may be running), says so once."""
    wb.STATE.mkdir(parents=True, exist_ok=True)
    handle = open(wb.STATE / "lock", "w")
    told = False
    while True:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return handle
        except OSError:
            if not told:
                print("… le job automatique travaille, j'attends son tour")
                told = True
            time.sleep(5)


def build(scheme: str) -> tuple[Path | None, str, float]:
    start = time.time()
    result = wb.run(
        ["/usr/bin/xcodebuild", "-project", str(wb.PROJECT / "Hexis.xcodeproj"), "-scheme", scheme, "-configuration", "Release",
         "-destination", "generic/platform=iOS", "-derivedDataPath", str(DERIVED / APPS[scheme]), "-allowProvisioningUpdates", "build"],
        3600,
    )
    log = result.stdout + result.stderr
    app = DERIVED / APPS[scheme] / f"Build/Products/Release-iphoneos/{scheme}.app"
    if result.returncode != 0 or not app.exists():
        errors = [l.strip() for l in log.splitlines() if "error:" in l]
        wb.log(f"compil: {scheme} build failed: " + " | ".join(errors[:4]))
        return None, " ".join(errors[:4]) or log[-300:], time.time() - start
    return app, "", time.time() - start


def install(app: Path, device: str, who: str, hers: bool = False) -> bool:
    start = time.time()
    if hers and wb.bundle_of(app) != wb.ELLE_BUNDLE:
        bad(f"{app.name} refusée pour son iPhone", "Seule Hexis Elle va sur son iPhone.")
        return False
    result = wb.run(["/usr/bin/xcrun", "devicectl", "device", "install", "app", "--device", device, str(app)], 900)
    if result.returncode != 0:
        text = (result.stderr or result.stdout)
        wb.log(f"compil: install of {app.name} on {who} failed: " + (text.strip().splitlines() or ["no output"])[-1])
        bad(f"{app.stem} pas installée sur {who}", hint(text))
        return False
    ok(f"{app.stem} installée sur {who} ({duration(time.time() - start)})")
    return True


def reachable(device: str | None, who: str, missing: str) -> bool:
    if device is None:
        bad(f"{who} : {missing}")
        return False
    if wb.probe(device) is None:
        bad(f"{who} injoignable", "Branche-le en USB (déverrouillé), ou même Wi-Fi que le Mac avec « Connect via network » activé dans Xcode.")
        return False
    return True


def status() -> int:
    for who, device, key in (("ton iPhone", wb.device_id(), "last_success"), ("son iPhone", wb.her_device(), "her_last_success")):
        age = (time.time() - wb.read_float(key)) / 86400
        state = "choisi" if device is None else ("répond" if wb.probe(device) is not None else "ne répond pas")
        left = "jamais installée par le script" if wb.read_float(key) == 0 else f"installée il y a {age:.1f} j, encore {max(0, 7 - age):.1f} j"
        print(f"{who} : {state} · {left}" if device else f"{who} : pas choisi")
    now = wb.datetime.now()
    print("Elle est chez toi en ce moment." if wb.at_hers(now) else "Elle n'est pas chez toi (visite : vendredi 18 h → dimanche 18 h).")
    return 0


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "hexis"
    if mode == "status":
        return status()
    if mode not in ("hexis", "hexis2"):
        print("Usage : compil hexis | compil hexis2 | compil status")
        return 2
    lock = take_lock()  # kept open until the end
    mine, hers = wb.device_id(), wb.her_device() if mode == "hexis2" else None
    targets: list[tuple[str, str, bool]] = []  # (who, device, is hers)
    if reachable(mine, "ton iPhone", "introuvable"):
        targets.append(("ton iPhone", mine, False))
    if mode == "hexis2" and reachable(hers, "son iPhone", "pas choisi (zsh Tools/her_phone.sh pair)"):
        targets.append(("son iPhone", hers, True))
    elif mode == "hexis2" and hers:
        (wb.STATE / "her_check").write_text("1")
        print("    → Je réessaierai seul à sa prochaine visite.")
    if not targets:
        return 1
    needed = [s for s in APPS if any(s == "HexisElle" or not is_hers for _, _, is_hers in targets)]
    print(f"… compilation ({' + '.join('Hexis Elle' if s == 'HexisElle' else s for s in needed)})")
    built: dict[str, Path] = {}
    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = {pool.submit(build, s): s for s in needed}
        for future in as_completed(futures):
            scheme = futures[future]
            app, error, seconds = future.result()
            if app is None:
                bad(f"{scheme} : compilation échouée", hint(error) if hint(error).startswith(("Xcode", "Plus")) else error[:200])
            else:
                built[scheme] = app
                ok(f"{scheme} compilée ({duration(seconds)})")
    failed = len(built) < len(needed)
    for who, device, is_hers in targets:
        for scheme in (["HexisElle"] if is_hers else list(APPS)):
            if scheme not in built:
                failed = True
            elif install(built[scheme], device, who, hers=is_hers):
                if scheme == "Hexis":
                    wb.write_float("last_success", time.time())
                elif is_hers:
                    # Outside her visit this is a first try: her next visit installs it again to be sure.
                    if wb.at_hers(wb.datetime.now()):
                        wb.write_float("her_last_success", time.time())
                        (wb.STATE / "her_check").unlink(missing_ok=True)
                    else:
                        (wb.STATE / "her_check").write_text("1")
                        print("    → Hors visite : réinstallée seule à sa prochaine visite, pour être sûr.")
            else:
                failed = True
                if is_hers:
                    (wb.STATE / "her_check").write_text("1")
    lock.close()
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
