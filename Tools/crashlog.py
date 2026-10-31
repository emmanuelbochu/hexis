"""Latest Hexis crash report of the user's iPhone, in ~15 lines. Run it FIRST when the app crashes or freezes.

Reports sync to ~/Library/Logs/CrashReporter/MobileDevice/<iPhone>/Hexis-*.ips when the iPhone is connected to the Mac.
Usage: python3 Tools/crashlog.py [elle] [n]   (elle = Hexis Elle's reports; n = how many reports back, default 0 = the latest)
       python3 Tools/crashlog.py <file.ips>
"""
import glob, json, os, sys

args = sys.argv[1:]
app = "HexisElle" if args[:1] == ["elle"] else "Hexis"
args = args[1:] if app == "HexisElle" else args
if args and args[0].endswith(".ips"):
    paths, back = [args[0]], 0
else:
    back = int(args[0]) if args else 0
    paths = sorted(glob.glob(os.path.expanduser(f"~/Library/Logs/CrashReporter/MobileDevice/*/{app}-*.ips")) +
                   glob.glob(os.path.expanduser(f"~/Library/Logs/DiagnosticReports/{app}-*.ips")), key=os.path.getmtime, reverse=True)
if len(paths) <= back:
    sys.exit(f"no {app} crash report (connect the iPhone to the Mac so the reports sync)")
raw = open(paths[back]).read()
head, _, body = raw.partition("\n")
try:
    d = json.loads(body)
except Exception:
    d = json.loads(raw)
print(os.path.basename(paths[back]), json.loads(head).get("timestamp", ""))
print("exception:", d.get("exception", {}).get("type"), d.get("exception", {}).get("signal"))
term = d.get("termination", {})
print("termination:", " | ".join(term.get("reasons", [])[:2]) if term else None)
if d.get("asi"):
    print("asi:", d["asi"])
images = d.get("usedImages", [])
for number, thread in enumerate(d.get("threads", [])):
    if not thread.get("triggered"):
        continue
    print(f"crashed thread {number} ({thread.get('queue') or thread.get('name') or ''}):")
    for frame in thread["frames"][:25]:
        image = images[frame["imageIndex"]]["name"] if frame.get("imageIndex") is not None and frame["imageIndex"] < len(images) else "?"
        if image.startswith("Hexis") or number == 0 and frame is thread["frames"][0]:
            print("  ", image, frame.get("symbol"), frame.get("sourceFile") or "", frame.get("sourceLine") or "")
print("hint: 0x8BADF00D = the main thread was blocked > 10 s (freeze/layout loop/heavy work); EXC_BAD_ACCESS/SIGABRT = real crash")
